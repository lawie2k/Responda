import hashlib
import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.core.exceptions import ApplicationError
from app.core.security import generate_session_token, hash_session_token
from app.core.sms_protocol import CLOCK_SKEW, MAX_MESSAGE_AGE, decode_message, device_key, encode64
from app.models import AuditLog, AuthSession, Report, SmsDevice, SmsGateway, SmsMessage, User
from app.schemas.sms import (
    GatewayCreate,
    GatewayCredential,
    GatewaySmsRequest,
    GatewaySmsResult,
    SmsDeviceCredential,
    SmsDeviceInfo,
)
from app.services.admin_auth import AuthenticatedAdmin
from app.services.mobile_reports import MobileReportService


def utc(value: datetime) -> datetime:
    return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)


class SmsService:
    def __init__(self, database: AsyncSession, settings: Settings) -> None:
        self.db = database
        self.settings = settings

    async def _reporter(self, user_id: uuid.UUID) -> User:
        user = await self.db.scalar(
            select(User)
            .where(
                User.user_id == user_id,
                User.role == "reporter",
                User.is_active.is_(True),
                User.deleted_at.is_(None),
                User.phone_number.is_not(None),
                User.phone_verified_at.is_not(None),
                User.privacy_notice_accepted_at.is_not(None),
            )
            .with_for_update()
            .execution_options(populate_existing=True)
        )
        if user is None:
            raise ApplicationError(
                "A verified phone account is required.", code="sms_phone_required", status_code=403
            )
        return user

    async def register_device(
        self, user_id: uuid.UUID, device_id: uuid.UUID
    ) -> SmsDeviceCredential:
        await self._reporter(user_id)
        now = datetime.now(UTC)
        device = await self.db.scalar(select(SmsDevice).where(SmsDevice.device_id == device_id))
        if device is not None:
            if (
                device.user_id != user_id
                or device.revoked_at is not None
                or utc(device.expires_at) <= now
            ):
                raise ApplicationError(
                    "Register a new SMS installation.", code="sms_device_conflict", status_code=409
                )
        else:
            count = await self.db.scalar(
                select(func.count())
                .select_from(SmsDevice)
                .where(
                    SmsDevice.user_id == user_id,
                    SmsDevice.revoked_at.is_(None),
                    SmsDevice.expires_at > now,
                )
            )
            if (count or 0) >= 5:
                raise ApplicationError(
                    "Revoke an existing SMS installation first.",
                    code="sms_device_limit",
                    status_code=409,
                )
            device = SmsDevice(
                device_id=device_id,
                user_id=user_id,
                created_at=now,
                expires_at=now + timedelta(days=180),
            )
            self.db.add(device)
            self._audit(user_id, "sms.device.registered", "sms_device", device_id)
        try:
            await self.db.commit()
        except IntegrityError:
            await self.db.rollback()
            raise ApplicationError(
                "Register a new SMS installation.", code="sms_device_conflict", status_code=409
            ) from None
        return SmsDeviceCredential(
            device_id=device_id,
            expires_at=device.expires_at,
            gateway_number=await self.db.scalar(
                select(SmsGateway.phone_number)
                .where(
                    SmsGateway.status == "active",
                    SmsGateway.deleted_at.is_(None),
                )
                .order_by(SmsGateway.created_at, SmsGateway.gateway_id)
                .limit(1)
            ),
            signing_key=encode64(
                device_key(self.settings.secret_key.get_secret_value(), device_id)
            ),
        )

    async def list_devices(self, user_id: uuid.UUID) -> list[SmsDeviceInfo]:
        await self._reporter(user_id)
        rows = (
            await self.db.scalars(
                select(SmsDevice)
                .where(
                    SmsDevice.user_id == user_id,
                    SmsDevice.revoked_at.is_(None),
                    SmsDevice.expires_at > datetime.now(UTC),
                )
                .order_by(SmsDevice.created_at.desc())
                .limit(5)
            )
        ).all()
        return [SmsDeviceInfo.model_validate(row) for row in rows]

    async def revoke_device(self, user_id: uuid.UUID, device_id: uuid.UUID) -> None:
        await self._reporter(user_id)
        device = await self.db.scalar(
            select(SmsDevice)
            .where(
                SmsDevice.device_id == device_id,
                SmsDevice.user_id == user_id,
            )
            .with_for_update()
        )
        if device is None:
            raise ApplicationError("SMS installation not found.", status_code=404)
        if device.revoked_at is None:
            device.revoked_at = datetime.now(UTC)
            self._audit(user_id, "sms.device.revoked", "sms_device", device_id)
        await self.db.commit()

    async def _admin(self, actor: AuthenticatedAdmin) -> None:
        now = datetime.now(UTC)
        user = await self.db.scalar(
            select(User)
            .where(
                User.user_id == actor.user.user_id,
                User.role == "admin",
                User.is_active.is_(True),
                User.deleted_at.is_(None),
            )
            .with_for_update()
            .execution_options(populate_existing=True)
        )
        session = await self.db.scalar(
            select(AuthSession)
            .where(
                AuthSession.session_id == actor.session.session_id,
                AuthSession.user_id == actor.user.user_id,
                AuthSession.revoked_at.is_(None),
                AuthSession.expires_at > now,
            )
            .execution_options(populate_existing=True)
        )
        if user is None or session is None:
            raise ApplicationError(
                "Only Super Admins may manage SMS gateways.",
                code="sms_gateway_forbidden",
                status_code=403,
            )

    async def create_gateway(
        self,
        actor: AuthenticatedAdmin,
        payload: GatewayCreate,
    ) -> GatewayCredential:
        await self._admin(actor)
        gateway_id = uuid.uuid4()
        token = "gateway_" + generate_session_token()
        self.db.add(
            SmsGateway(
                gateway_id=gateway_id,
                name=payload.name,
                phone_number=payload.phone_number,
                device_identifier=payload.device_identifier,
                api_key_hash=hash_session_token(token),
                status="active",
            )
        )
        self._audit(actor.user.user_id, "sms.gateway.created", "sms_gateway", gateway_id)
        try:
            await self.db.commit()
        except IntegrityError:
            await self.db.rollback()
            raise ApplicationError(
                "This gateway identity is already registered.",
                code="sms_gateway_conflict",
                status_code=409,
            ) from None
        return GatewayCredential(gateway_id=gateway_id, access_token=token)

    async def revoke_gateway(self, actor: AuthenticatedAdmin, gateway_id: uuid.UUID) -> None:
        await self._admin(actor)
        gateway = await self.db.scalar(
            select(SmsGateway)
            .where(
                SmsGateway.gateway_id == gateway_id,
                SmsGateway.deleted_at.is_(None),
            )
            .with_for_update()
        )
        if gateway is None:
            raise ApplicationError("SMS gateway not found.", status_code=404)
        gateway.status = "inactive"
        gateway.updated_at = datetime.now(UTC)
        self._audit(actor.user.user_id, "sms.gateway.revoked", "sms_gateway", gateway_id)
        await self.db.commit()

    async def rotate_gateway(
        self,
        actor: AuthenticatedAdmin,
        gateway_id: uuid.UUID,
    ) -> GatewayCredential:
        await self._admin(actor)
        gateway = await self.db.scalar(
            select(SmsGateway)
            .where(
                SmsGateway.gateway_id == gateway_id,
                SmsGateway.deleted_at.is_(None),
            )
            .with_for_update()
        )
        if gateway is None:
            raise ApplicationError("SMS gateway not found.", status_code=404)
        token = "gateway_" + generate_session_token()
        gateway.api_key_hash = hash_session_token(token)
        gateway.status = "active"
        gateway.updated_at = datetime.now(UTC)
        self._audit(actor.user.user_id, "sms.gateway.rotated", "sms_gateway", gateway_id)
        await self.db.commit()
        return GatewayCredential(gateway_id=gateway_id, access_token=token)

    async def authenticate_gateway(self, token: str | None) -> SmsGateway:
        if token and token.startswith("gateway_") and len(token) <= 150:
            gateway = await self.db.scalar(
                select(SmsGateway)
                .where(
                    SmsGateway.api_key_hash == hash_session_token(token),
                    SmsGateway.status == "active",
                    SmsGateway.deleted_at.is_(None),
                )
                .with_for_update()
                .execution_options(populate_existing=True)
            )
            if gateway is not None:
                return gateway
        raise ApplicationError(
            "Gateway authentication failed.", code="sms_gateway_unauthorized", status_code=401
        )

    async def ingest(self, gateway: SmsGateway, payload: GatewaySmsRequest) -> GatewaySmsResult:
        rejected = GatewaySmsResult(status="rejected")
        decoded = decode_message(payload.body, self.settings.secret_key.get_secret_value())
        if decoded is None:
            return rejected
        device_id, content = decoded
        now = datetime.now(UTC)
        sent = datetime.fromtimestamp(content.t, UTC)
        received = utc(payload.received_at)
        if (
            not now - MAX_MESSAGE_AGE <= sent <= now + CLOCK_SKEW
            or not now - MAX_MESSAGE_AGE <= received <= now + CLOCK_SKEW
            or sent > received + CLOCK_SKEW
        ):
            return rejected
        device = await self.db.scalar(select(SmsDevice).where(SmsDevice.device_id == device_id))
        if device is None:
            return rejected
        # The user row is always locked before its installation, matching registration/revocation.
        try:
            reporter = await self._reporter(device.user_id)
        except ApplicationError:
            return rejected
        device = await self.db.scalar(
            select(SmsDevice)
            .where(
                SmsDevice.device_id == device_id,
            )
            .with_for_update()
            .execution_options(populate_existing=True)
        )
        if (
            device is None
            or device.revoked_at is not None
            or utc(device.expires_at) <= now
            or sent < utc(device.created_at) - CLOCK_SKEW
            or reporter.phone_number != payload.sender_number
        ):
            return rejected
        digest = hashlib.sha256(payload.body.encode("ascii")).hexdigest()
        receipt = await self.db.scalar(
            select(SmsMessage).where(
                SmsMessage.gateway_id == gateway.gateway_id,
                SmsMessage.provider_message_id == payload.provider_message_id,
            )
        )
        if receipt is None:
            receipt = await self.db.scalar(
                select(SmsMessage).where(
                    SmsMessage.client_report_id == uuid.UUID(hex=content.c),
                    SmsMessage.parse_status == "accepted",
                )
            )
        if receipt is not None:
            if (
                receipt.deleted_at is not None
                or receipt.payload_sha256 != digest
                or receipt.sender_number != payload.sender_number
            ):
                return rejected
            report = await self.db.scalar(
                select(Report).where(
                    Report.report_id == receipt.report_id,
                    Report.deleted_at.is_(None),
                )
            )
            if report is None:
                return rejected
            gateway.last_seen_at = now
            await self.db.commit()
            return GatewaySmsResult(status="duplicate", report_id=report.report_id)
        report = await self.db.scalar(
            select(Report).where(
                Report.client_report_id == uuid.UUID(hex=content.c),
            )
        )
        duplicate = report is not None
        if report is not None:
            if report.deleted_at is not None or report.reporter_id != reporter.user_id:
                return rejected
        else:
            try:
                report = await MobileReportService(self.db).stage_report(
                    reporter=reporter,
                    payload=content.report(),
                    source="app_sms",
                )
            except ApplicationError:
                return rejected
            try:
                await self.db.flush()
            except IntegrityError:
                await self.db.rollback()
                raise ApplicationError(
                    "Retry this queued SMS.", code="sms_retry", status_code=503
                ) from None
        self.db.add(
            SmsMessage(
                sms_id=uuid.uuid4(),
                gateway_id=gateway.gateway_id,
                provider_message_id=payload.provider_message_id,
                sender_number=payload.sender_number,
                raw_message_body="",
                device_id=device_id,
                payload_sha256=digest,
                protocol_version="RSP1",
                client_report_id=uuid.UUID(hex=content.c),
                signature=payload.body.rsplit(".", 1)[1],
                signature_valid=True,
                parse_status="accepted",
                report_id=report.report_id,
                received_at=received,
                processed_at=now,
            )
        )
        gateway.last_seen_at = now
        try:
            await self.db.commit()
        except IntegrityError:
            await self.db.rollback()
            # A concurrent transport won the unique client ID; retry the unchanged queued item.
            raise ApplicationError(
                "Retry this queued SMS.", code="sms_retry", status_code=503
            ) from None
        return GatewaySmsResult(
            status="duplicate" if duplicate else "accepted", report_id=report.report_id
        )

    def _audit(self, actor: uuid.UUID, action: str, entity: str, entity_id: uuid.UUID) -> None:
        self.db.add(
            AuditLog(actor_user_id=actor, action=action, entity_type=entity, entity_id=entity_id)
        )
