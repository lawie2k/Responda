import asyncio
import base64
import hashlib
import hmac
import json
import uuid
from datetime import UTC, datetime, timedelta
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock

import pytest
from sqlalchemy import create_engine, event, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.exceptions import ApplicationError
from app.core.security import hash_session_token
from app.core.sms_protocol import SmsContent, decode_message, device_key, encode64, encode_message
from app.db.base import Base
from app.models import (
    AuditLog,
    AuthSession,
    IncidentType,
    Report,
    ReportEvent,
    ReportLocation,
    SmsDevice,
    SmsGateway,
    SmsMessage,
    User,
)
from app.schemas.sms import GatewayCreate, GatewaySmsRequest
from app.services.admin_auth import AuthenticatedAdmin
from app.services.mobile_reports import MobileReportService
from app.services.sms import SmsService

PHONE = "+639000000001"


@pytest.fixture
def sms_database():
    engine = create_engine("sqlite://")

    @event.listens_for(engine, "connect")
    def configure(connection, _):
        connection.create_function("gen_random_uuid", 0, lambda: uuid.uuid4().hex)
        connection.execute("PRAGMA foreign_keys=ON")

    Base.metadata.create_all(engine)
    with Session(engine, expire_on_commit=False) as db:
        async_db = MagicMock(spec=AsyncSession)
        async_db.get_bind.return_value = engine
        for method in ("execute", "scalar", "scalars", "flush", "commit", "rollback"):
            setattr(async_db, method, AsyncMock(side_effect=getattr(db, method)))
        async_db.add.side_effect = db.add
        async_db.add_all.side_effect = db.add_all
        settings = Settings(_env_file=None, environment="testing")
        now = datetime.now(UTC)
        reporter = User(
            user_id=uuid.uuid4(),
            full_name="Synthetic citizen",
            phone_number=PHONE,
            role="reporter",
            is_active=True,
            phone_verified_at=now,
            privacy_notice_accepted_at=now,
        )
        admin = User(
            user_id=uuid.uuid4(),
            full_name="Synthetic admin",
            email="admin@example.invalid",
            role="admin",
            is_active=True,
        )
        db.add_all(
            [
                reporter,
                admin,
                IncidentType(code="fire", name="Fire", active=True, default_priority="high"),
            ]
        )
        db.commit()
        session = AuthSession(
            session_id=uuid.uuid4(),
            user_id=admin.user_id,
            refresh_token_hash="synthetic-session",
            expires_at=now + timedelta(days=1),
        )
        db.add(session)
        db.commit()
        yield SmsService(async_db, settings), db, reporter, AuthenticatedAdmin(admin, session)
    engine.dispose()


def content(**changes):
    data = dict(
        c=uuid.uuid4().hex,
        t=int(datetime.now(UTC).timestamp()),
        i="fire",
        d="Synthetic smoke report for an automated test.",
        l="Synthetic test area",
        x=7.1,
        y=125.9,
        p=True,
        a=False,
        g=True,
    )
    return SmsContent(**(data | changes))


async def setup(service, reporter, admin):
    device = await service.register_device(reporter.user_id, uuid.uuid4())
    credential = await service.create_gateway(
        admin,
        GatewayCreate(
            name="Synthetic gateway", phone_number="+639000000002", device_identifier="test-phone"
        ),
    )
    gateway = await service.authenticate_gateway(credential.access_token)
    return device, credential, gateway


def message(service, device, value=None, **changes):
    body = encode_message(
        device.device_id,
        device_key(service.settings.secret_key.get_secret_value(), device.device_id),
        value or content(),
    )
    return GatewaySmsRequest(
        provider_message_id="inbox-1", sender_number=PHONE, body=body, received_at=datetime.now(UTC)
    ).model_copy(update=changes)


def test_signed_sms_creates_private_atomic_report_and_retries_are_idempotent(sms_database):
    service, db, reporter, admin = sms_database

    async def exercise():
        device, credential, gateway = await setup(service, reporter, admin)
        assert db.get(SmsGateway, gateway.gateway_id).api_key_hash == hash_session_token(
            credential.access_token
        )
        refreshed = await service.register_device(reporter.user_id, device.device_id)
        assert refreshed.signing_key == device.signing_key
        assert refreshed.gateway_number == "+639000000002"
        request = message(service, device)
        result = await service.ingest(gateway, request)
        assert result.status == "accepted"
        report = db.get(Report, result.report_id)
        assert report.source == "app_sms" and report.reporter_id == reporter.user_id
        assert report.status == "new" and report.verification_status == "pending"
        assert db.scalar(select(ReportLocation)).latitude == 7.1
        assert db.scalar(select(ReportEvent)).event_type == "report.created"
        receipt = db.scalar(select(SmsMessage))
        assert receipt.raw_message_body == "" and receipt.signature_valid
        for payload in (request, request.model_copy(update={"provider_message_id": "inbox-2"})):
            again = await service.ingest(gateway, payload)
            assert again.status == "duplicate" and again.report_id == result.report_id
        assert len(db.scalars(select(Report)).all()) == 1
        assert len(db.scalars(select(SmsMessage)).all()) == 1
        assert all(
            report.description_original not in (audit.details or "")
            for audit in db.scalars(select(AuditLog))
        )

    asyncio.run(exercise())


@pytest.mark.parametrize(
    "failure",
    [
        "plain",
        "tamper",
        "sender",
        "unknown_device",
        "revoked",
        "expired",
        "inactive",
        "deleted",
        "unverified",
        "consent",
        "old",
        "future",
        "early_receipt",
        "before_registration",
        "disabled_type",
    ],
)
def test_invalid_sms_never_creates_a_report_or_retains_private_message(sms_database, failure):
    service, db, reporter, admin = sms_database

    async def exercise():
        device, _, gateway = await setup(service, reporter, admin)
        request = message(service, device)
        row = db.get(SmsDevice, device.device_id)
        if failure == "plain":
            request.body = "A private ordinary message."
        elif failure == "tamper":
            request.body = request.body[:-2] + "xx"
        elif failure == "sender":
            request.sender_number = "+639000000003"
        elif failure == "unknown_device":
            fake_device = device.model_copy(update={"device_id": uuid.uuid4()})
            request = message(service, fake_device)
        elif failure == "revoked":
            row.revoked_at = datetime.now(UTC)
        elif failure == "expired":
            row.expires_at = datetime.now(UTC) - timedelta(seconds=1)
        elif failure == "inactive":
            reporter.is_active = False
        elif failure == "deleted":
            reporter.deleted_at = datetime.now(UTC)
        elif failure == "unverified":
            reporter.phone_verified_at = None
        elif failure == "consent":
            reporter.privacy_notice_accepted_at = None
        elif failure == "old":
            request = message(
                service, device, content(t=int((datetime.now(UTC) - timedelta(days=8)).timestamp()))
            )
        elif failure == "future":
            request = message(
                service,
                device,
                content(t=int((datetime.now(UTC) + timedelta(hours=1)).timestamp())),
            )
        elif failure == "early_receipt":
            request.received_at = datetime.now(UTC) - timedelta(hours=1)
        elif failure == "before_registration":
            row.created_at = datetime.now(UTC) + timedelta(hours=1)
        elif failure == "disabled_type":
            db.scalar(select(IncidentType)).active = False
        db.commit()
        assert (await service.ingest(gateway, request)).status == "rejected"
        assert db.scalar(select(Report)) is None
        assert db.scalar(select(SmsMessage)) is None

    asyncio.run(exercise())


def test_reused_delivery_id_changed_payload_and_deleted_reports_do_not_resurrect(sms_database):
    service, db, reporter, admin = sms_database

    async def exercise():
        device, _, gateway = await setup(service, reporter, admin)
        value = content()
        original = message(service, device, value)
        result = await service.ingest(gateway, original)
        for altered in (
            message(service, device),
            message(service, device, value.model_copy(update={"d": "Different test content"})),
        ):
            assert (await service.ingest(gateway, altered)).status == "rejected"
        db.get(Report, result.report_id).soft_delete()
        db.commit()
        assert (await service.ingest(gateway, original)).status == "rejected"
        assert len(db.scalars(select(Report)).all()) == 1

    asyncio.run(exercise())


def test_cross_transport_duplicate_keeps_the_original_report(sms_database):
    service, db, reporter, admin = sms_database

    async def exercise():
        device, _, gateway = await setup(service, reporter, admin)
        value = content()
        online = await MobileReportService(service.db).create_report(
            reporter=reporter, payload=value.report()
        )
        result = await service.ingest(gateway, message(service, device, value))
        assert result.status == "duplicate" and result.report_id == online.report_id
        assert db.get(Report, result.report_id).source == "app_api"

    asyncio.run(exercise())


def test_gateway_and_installation_revocation_take_effect_immediately(sms_database):
    service, db, reporter, admin = sms_database

    async def exercise():
        device, credential, gateway = await setup(service, reporter, admin)
        await service.revoke_device(reporter.user_id, device.device_id)
        assert (await service.ingest(gateway, message(service, device))).status == "rejected"
        await service.revoke_gateway(admin, gateway.gateway_id)
        for token in (credential.access_token, None, "mobile_fake", "gateway_invalid"):
            with pytest.raises(ApplicationError):
                await service.authenticate_gateway(token)
        assert db.get(SmsGateway, gateway.gateway_id).status == "inactive"
        rotated = await service.rotate_gateway(admin, gateway.gateway_id)
        assert rotated.access_token != credential.access_token
        assert (
            await service.authenticate_gateway(rotated.access_token)
        ).gateway_id == gateway.gateway_id
        with pytest.raises(ApplicationError):
            await service.authenticate_gateway(credential.access_token)
        assert await service.list_devices(reporter.user_id) == []

    asyncio.run(exercise())


def test_registration_limits_ownership_and_admin_authority(sms_database):
    service, db, reporter, admin = sms_database

    async def exercise():
        other = User(
            user_id=uuid.uuid4(),
            full_name="Another tester",
            phone_number="+639000000003",
            phone_verified_at=datetime.now(UTC),
            privacy_notice_accepted_at=datetime.now(UTC),
            role="reporter",
            is_active=True,
        )
        db.add(other)
        db.commit()
        device = await service.register_device(reporter.user_id, uuid.uuid4())
        with pytest.raises(ApplicationError):
            await service.register_device(other.user_id, device.device_id)
        with pytest.raises(ApplicationError):
            await service.revoke_device(other.user_id, device.device_id)
        for _ in range(4):
            await service.register_device(reporter.user_id, uuid.uuid4())
        with pytest.raises(ApplicationError) as error:
            await service.register_device(reporter.user_id, uuid.uuid4())
        assert error.value.code == "sms_device_limit"
        admin.user.role = "operations_admin"
        db.commit()
        with pytest.raises(ApplicationError):
            await service.create_gateway(
                admin, GatewayCreate(name="Test", phone_number=PHONE, device_identifier="test")
            )
        reporter.phone_verified_at = None
        db.commit()
        with pytest.raises(ApplicationError):
            await service.register_device(reporter.user_id, uuid.uuid4())

    asyncio.run(exercise())


def test_protocol_rejects_unknown_versions_truncation_and_ambiguous_json():
    identifier = uuid.uuid4()
    secret = "synthetic-test-secret"
    key = device_key(secret, identifier)
    body = encode_message(identifier, key, content())
    assert decode_message(body, secret) is not None
    for malformed in (body.replace("RSP1", "RSP2"), body[:-1], body + " ", "x" * 2049):
        assert decode_message(malformed, secret) is None
    payload = '{"c":"' + uuid.uuid4().hex + '","c":"' + uuid.uuid4().hex + '"}'
    unsigned = f"RSP1.{identifier.hex}.{encode64(payload.encode())}"
    signed = unsigned + "." + encode64(hmac.digest(key, unsigned.encode(), "sha256"))
    assert decode_message(signed, secret) is None
    assert len(base64.urlsafe_b64decode(encode64(hashlib.sha256(b"test").digest()) + "=")) == 32


def test_python_accepts_the_shared_flutter_protocol_vector():
    vector = json.loads((Path(__file__).parents[3] / "mobile/test/fixtures/rsp1.json").read_text())
    decoded = decode_message(vector["body"], vector["secret"])
    assert decoded is not None
    assert str(decoded[0]) == vector["device"]
    assert str(decoded[1].report().client_report_id) == vector["client"]


def test_reference_encoder_is_bounded_and_preserves_utf8():
    identifier = uuid.uuid4()
    secret = "synthetic-test-secret"
    key = device_key(secret, identifier)
    value = content(d="Synthetic text: ñ and ü are preserved.")
    decoded = decode_message(encode_message(identifier, key, value), secret)
    assert decoded is not None and decoded[1].d == value.d
    with pytest.raises(ValueError):
        encode_message(identifier, key, content(d="😀" * 300, l="😀" * 100))


def test_receipt_failure_rolls_back_report_location_and_events(sms_database):
    service, db, reporter, admin = sms_database

    async def exercise():
        device, _, gateway = await setup(service, reporter, admin)
        service.db.commit = AsyncMock(side_effect=IntegrityError("synthetic", {}, Exception()))
        with pytest.raises(ApplicationError) as error:
            await service.ingest(gateway, message(service, device))
        assert error.value.status_code == 503
        for model in (Report, ReportLocation, ReportEvent, SmsMessage):
            assert db.scalar(select(model)) is None

    asyncio.run(exercise())


@pytest.mark.parametrize("problem", ["revoked_session", "expired_session", "deleted_admin"])
def test_gateway_provisioning_rechecks_actor_session(sms_database, problem):
    service, db, reporter, admin = sms_database
    if problem == "revoked_session":
        admin.session.revoked_at = datetime.now(UTC)
    elif problem == "expired_session":
        admin.session.expires_at = datetime.now(UTC) - timedelta(seconds=1)
    else:
        admin.user.deleted_at = datetime.now(UTC)
    db.commit()
    with pytest.raises(ApplicationError):
        asyncio.run(
            service.create_gateway(
                admin, GatewayCreate(name="Test", phone_number=PHONE, device_identifier="test")
            )
        )
    assert db.scalar(select(SmsGateway)) is None
