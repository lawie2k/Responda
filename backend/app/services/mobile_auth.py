import hashlib
import hmac
import secrets
import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import select, text, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Environment, Settings
from app.core.exceptions import ApplicationError
from app.core.security import generate_session_token, hash_session_token
from app.models import AuditLog, AuthSession, OtpChallenge, User
from app.schemas.mobile_auth import (
    MobileLogin,
    MobileProfileUpdate,
    MobileSession,
    MobileUser,
    OtpResponse,
    OtpVerify,
)


def utc(value: datetime) -> datetime:
    return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)


class MobileAuthService:
    def __init__(self, database: AsyncSession, settings: Settings) -> None:
        self.db = database
        self.settings = settings

    async def _lock_phone(self, phone: str) -> None:
        # Serialize first registration and resend/verify across API workers.
        if self.db.get_bind().dialect.name == "postgresql":
            key = int.from_bytes(hashlib.sha256(phone.encode()).digest()[:8], signed=True)
            await self.db.execute(text("SELECT pg_advisory_xact_lock(:key)"), {"key": key})

    def _hash_code(self, challenge_id: uuid.UUID, code: str) -> str:
        return hmac.new(
            self.settings.secret_key.get_secret_value().encode(),
            f"mobile-login:{challenge_id}:{code}".encode(),
            hashlib.sha256,
        ).hexdigest()

    async def request_code(self, phone: str) -> OtpResponse:
        if not self.settings.mobile_dev_otp_enabled or self.settings.environment not in {
            Environment.DEVELOPMENT,
            Environment.TESTING,
        }:
            raise ApplicationError(
                "SMS verification is not configured yet.",
                code="sms_unavailable",
                status_code=503,
            )
        await self._lock_phone(phone)
        now = datetime.now(UTC)
        latest = await self.db.scalar(
            select(OtpChallenge)
            .where(
                OtpChallenge.phone_number == phone,
                OtpChallenge.purpose == "mobile_login",
            )
            .order_by(OtpChallenge.created_at.desc())
            .limit(1)
        )
        if latest is not None and utc(latest.created_at) > now - timedelta(seconds=60):
            raise ApplicationError(
                "Wait one minute before requesting another code.",
                code="otp_rate_limited",
                status_code=429,
                headers={"Retry-After": "60"},
            )
        await self.db.execute(
            update(OtpChallenge)
            .where(
                OtpChallenge.phone_number == phone,
                OtpChallenge.purpose == "mobile_login",
                OtpChallenge.consumed_at.is_(None),
            )
            .values(consumed_at=now)
        )
        challenge_id = uuid.uuid4()
        code = f"{secrets.randbelow(1_000_000):06d}"
        expires = now + timedelta(minutes=5)
        self.db.add(
            OtpChallenge(
                challenge_id=challenge_id,
                phone_number=phone,
                purpose="mobile_login",
                code_hash=self._hash_code(challenge_id, code),
                attempt_count=0,
                expires_at=expires,
                created_at=now,
            )
        )
        await self.db.commit()
        return OtpResponse(challenge_id=challenge_id, expires_at=expires, development_code=code)

    @staticmethod
    def invalid_code() -> ApplicationError:
        return ApplicationError(
            "The code is incorrect or expired. Request another code if needed.",
            code="otp_invalid",
            status_code=401,
        )

    async def verify(self, payload: OtpVerify) -> MobileLogin:
        if not self.settings.mobile_dev_otp_enabled:
            raise ApplicationError(
                "SMS verification is not configured yet.",
                code="sms_unavailable",
                status_code=503,
            )
        if not payload.privacy_notice_accepted:
            raise ApplicationError("Read and accept the privacy notice.", code="privacy_required")
        await self._lock_phone(payload.phone_number)
        challenge = await self.db.scalar(
            select(OtpChallenge)
            .where(
                OtpChallenge.challenge_id == payload.challenge_id,
                OtpChallenge.phone_number == payload.phone_number,
                OtpChallenge.purpose == "mobile_login",
            )
            .with_for_update()
            .execution_options(populate_existing=True)
        )
        now = datetime.now(UTC)
        if (
            challenge is None
            or challenge.consumed_at is not None
            or utc(challenge.expires_at) <= now
            or challenge.attempt_count >= 5
        ):
            raise self.invalid_code()
        challenge.attempt_count += 1
        if not hmac.compare_digest(
            challenge.code_hash,
            self._hash_code(challenge.challenge_id, payload.code.get_secret_value()),
        ):
            if challenge.attempt_count >= 5:
                challenge.consumed_at = now
            await self.db.commit()
            raise self.invalid_code()
        challenge.consumed_at = now
        user = await self.db.scalar(
            select(User)
            .where(
                User.phone_number == payload.phone_number,
            )
            .with_for_update()
            .execution_options(populate_existing=True)
        )
        if user is not None and (
            user.deleted_at is not None or not user.is_active or user.role != "reporter"
        ):
            await self.db.commit()
            raise ApplicationError(
                "This account cannot sign in. Contact the municipal office.",
                code="account_unavailable",
                status_code=403,
            )
        if user is None:
            user = User(
                user_id=uuid.uuid4(),
                full_name="",
                phone_number=payload.phone_number,
                role="reporter",
                is_active=True,
            )
            self.db.add(user)
            await self.db.flush()
        user.phone_verified_at = now
        user.privacy_notice_accepted_at = now
        user.updated_at = now
        sessions = (
            await self.db.scalars(
                select(AuthSession)
                .where(
                    AuthSession.user_id == user.user_id,
                    AuthSession.revoked_at.is_(None),
                    AuthSession.expires_at > now,
                )
                .order_by(AuthSession.created_at.desc(), AuthSession.session_id.desc())
            )
        ).all()
        for old in sessions[4:]:
            old.revoked_at = now
        token = "mobile_" + generate_session_token()
        session = AuthSession(
            created_at=now,
            session_id=uuid.uuid4(),
            user_id=user.user_id,
            refresh_token_hash=hash_session_token(token),
            expires_at=now + timedelta(seconds=self.settings.mobile_session_ttl_seconds),
        )
        self.db.add(session)
        self._audit(user, "mobile.auth.login")
        await self.db.commit()
        return MobileLogin(
            user=MobileUser.model_validate(user), expires_at=session.expires_at, access_token=token
        )

    async def authenticate(self, token: str | None) -> tuple[User, AuthSession]:
        error = ApplicationError(
            "Sign in with your phone number.", code="mobile_session_invalid", status_code=401
        )
        if not token or not token.startswith("mobile_"):
            raise error
        row = (
            await self.db.execute(
                select(User, AuthSession)
                .join(
                    AuthSession,
                    AuthSession.user_id == User.user_id,
                )
                .where(
                    AuthSession.refresh_token_hash == hash_session_token(token),
                    AuthSession.revoked_at.is_(None),
                    AuthSession.expires_at > datetime.now(UTC),
                    User.role == "reporter",
                    User.is_active.is_(True),
                    User.deleted_at.is_(None),
                    User.phone_verified_at.is_not(None),
                    User.privacy_notice_accepted_at.is_not(None),
                )
                .with_for_update(of=User)
                .execution_options(populate_existing=True)
            )
        ).one_or_none()
        if row is None:
            raise error
        return row[0], row[1]

    async def profile(self, token: str | None) -> MobileSession:
        user, session = await self.authenticate(token)
        return MobileSession(user=MobileUser.model_validate(user), expires_at=session.expires_at)

    async def update_profile(
        self, token: str | None, payload: MobileProfileUpdate
    ) -> MobileSession:
        user, session = await self.authenticate(token)
        user.full_name, user.barangay = payload.full_name, payload.barangay or None
        user.updated_at = datetime.now(UTC)
        self._audit(user, "mobile.profile.updated")
        await self.db.commit()
        return MobileSession(user=MobileUser.model_validate(user), expires_at=session.expires_at)

    async def logout(self, token: str | None) -> None:
        user, session = await self.authenticate(token)
        session.revoked_at = datetime.now(UTC)
        self._audit(user, "mobile.auth.logout")
        await self.db.commit()

    def _audit(self, user: User, action: str) -> None:
        self.db.add(
            AuditLog(
                actor_user_id=user.user_id,
                entity_id=user.user_id,
                entity_type="user",
                action=action,
            )
        )
