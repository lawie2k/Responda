import asyncio
import uuid
from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock

import pytest
from pydantic import SecretStr
from sqlalchemy import create_engine, event, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.exceptions import ApplicationError
from app.core.security import hash_session_token
from app.db.base import Base
from app.models import AuditLog, AuthSession, OtpChallenge, User
from app.schemas.mobile_auth import MobileProfileUpdate, OtpVerify
from app.services.mobile_auth import MobileAuthService

PHONE = "+639000000001"


@pytest.fixture
def mobile_database():
    engine = create_engine("sqlite://")

    @event.listens_for(engine, "connect")
    def setup(connection, _):
        connection.create_function("gen_random_uuid", 0, lambda: uuid.uuid4().hex)

    Base.metadata.create_all(engine)
    with Session(engine, expire_on_commit=False) as db:
        database = MagicMock(spec=AsyncSession)
        database.get_bind.return_value = engine
        for method in ("execute", "scalar", "scalars", "flush", "commit", "rollback"):
            setattr(database, method, AsyncMock(side_effect=getattr(db, method)))
        database.add.side_effect = db.add
        settings = Settings(_env_file=None, environment="testing", mobile_dev_otp_enabled=True)
        yield MobileAuthService(database, settings), db
    engine.dispose()


async def login(service):
    challenge = await service.request_code(PHONE)
    return await service.verify(
        OtpVerify(
            phone_number=PHONE,
            challenge_id=challenge.challenge_id,
            code=challenge.development_code,
            privacy_notice_accepted=True,
        )
    )


def test_signup_profile_restore_logout_and_no_sensitive_audit(mobile_database):
    service, db = mobile_database

    async def exercise():
        result = await login(service)
        assert result.user.full_name == "" and result.user.barangay is None
        assert result.access_token.startswith("mobile_")
        stored = db.scalar(select(AuthSession))
        assert stored.refresh_token_hash == hash_session_token(result.access_token)
        updated = await service.update_profile(
            result.access_token,
            MobileProfileUpdate(full_name="  Synthetic citizen  ", barangay="Kingking"),
        )
        assert updated.user.full_name == "Synthetic citizen"
        assert (await service.profile(result.access_token)).user.barangay == "Kingking"
        await service.logout(result.access_token)
        with pytest.raises(ApplicationError, match="Sign in"):
            await service.profile(result.access_token)
        for audit in db.scalars(select(AuditLog)):
            assert audit.details is None
        assert db.scalar(select(OtpChallenge)).consumed_at is not None

    asyncio.run(exercise())


@pytest.mark.parametrize("failure", ["expired", "consumed", "wrong_phone", "missing", "wrong_code"])
def test_invalid_challenges_never_create_accounts(mobile_database, failure):
    service, db = mobile_database

    async def exercise():
        challenge = await service.request_code(PHONE)
        row = db.scalar(select(OtpChallenge))
        if failure == "expired":
            row.expires_at = datetime.now(UTC) - timedelta(seconds=1)
        if failure == "consumed":
            row.consumed_at = datetime.now(UTC)
        db.commit()
        with pytest.raises(ApplicationError) as caught:
            await service.verify(
                OtpVerify(
                    phone_number="+639000000002" if failure == "wrong_phone" else PHONE,
                    challenge_id=uuid.uuid4() if failure == "missing" else challenge.challenge_id,
                    code="wrong!" if failure == "wrong_code" else challenge.development_code,
                    privacy_notice_accepted=True,
                )
            )
        assert caught.value.code == "otp_invalid"
        assert db.scalar(select(User)) is None

    asyncio.run(exercise())


def test_five_wrong_attempts_consume_code_and_valid_code_cannot_replay(mobile_database):
    service, db = mobile_database

    async def exercise():
        challenge = await service.request_code(PHONE)
        payload = OtpVerify(
            phone_number=PHONE,
            challenge_id=challenge.challenge_id,
            code="wrong!",
            privacy_notice_accepted=True,
        )
        for _ in range(5):
            with pytest.raises(ApplicationError):
                await service.verify(payload)
        row = db.scalar(select(OtpChallenge))
        assert row.attempt_count == 5 and row.consumed_at is not None
        with pytest.raises(ApplicationError):
            await service.verify(
                payload.model_copy(update={"code": SecretStr(challenge.development_code)})
            )

    asyncio.run(exercise())


def test_resend_cooldown_invalidates_old_code(mobile_database):
    service, db = mobile_database

    async def exercise():
        first = await service.request_code(PHONE)
        with pytest.raises(ApplicationError) as caught:
            await service.request_code(PHONE)
        assert caught.value.status_code == 429
        db.scalar(select(OtpChallenge)).created_at = datetime.now(UTC) - timedelta(minutes=2)
        db.commit()
        second = await service.request_code(PHONE)
        assert second.challenge_id != first.challenge_id
        with pytest.raises(ApplicationError):
            await service.verify(
                OtpVerify(
                    phone_number=PHONE,
                    challenge_id=first.challenge_id,
                    code=first.development_code,
                    privacy_notice_accepted=True,
                )
            )

    asyncio.run(exercise())


@pytest.mark.parametrize("state", ["inactive", "deleted", "admin"])
def test_unavailable_accounts_cannot_login(mobile_database, state):
    service, db = mobile_database
    db.add(
        User(
            user_id=uuid.uuid4(),
            full_name="Synthetic",
            phone_number=PHONE,
            role="admin" if state == "admin" else "reporter",
            is_active=state != "inactive",
            deleted_at=datetime.now(UTC) if state == "deleted" else None,
        )
    )
    db.commit()
    with pytest.raises(ApplicationError) as caught:
        asyncio.run(login(service))
    assert caught.value.status_code == 403
    assert db.scalar(select(AuthSession)) is None


def test_recovery_reuses_account_and_limits_live_sessions(mobile_database):
    service, db = mobile_database

    async def exercise():
        original = await login(service)
        for _ in range(5):
            for row in db.scalars(select(OtpChallenge)):
                row.created_at = datetime.now(UTC) - timedelta(minutes=2)
            db.commit()
            result = await login(service)
            assert result.user.user_id == original.user.user_id
        sessions = db.scalars(select(AuthSession)).all()
        assert len(sessions) == 6 and sum(s.revoked_at is None for s in sessions) == 5
        with pytest.raises(ApplicationError):
            await service.profile(original.access_token)

    asyncio.run(exercise())


@pytest.mark.parametrize("state", ["inactive", "deleted", "unverified", "expired", "revoked"])
def test_session_rechecks_account_and_session(mobile_database, state):
    service, db = mobile_database

    async def exercise():
        result = await login(service)
        user = db.scalar(select(User))
        session = db.scalar(select(AuthSession))
        if state == "inactive":
            user.is_active = False
        if state == "deleted":
            user.deleted_at = datetime.now(UTC)
        if state == "unverified":
            user.phone_verified_at = None
        if state == "expired":
            session.expires_at = datetime.now(UTC) - timedelta(seconds=1)
        if state == "revoked":
            session.revoked_at = datetime.now(UTC)
        db.commit()
        with pytest.raises(ApplicationError):
            await service.profile(result.access_token)

    asyncio.run(exercise())


def test_disabled_delivery_and_missing_consent(mobile_database):
    service, db = mobile_database
    service.settings.mobile_dev_otp_enabled = False
    with pytest.raises(ApplicationError) as caught:
        asyncio.run(service.request_code(PHONE))
    assert caught.value.status_code == 503
    assert db.scalar(select(OtpChallenge)) is None
    service.settings.mobile_dev_otp_enabled = True
    with pytest.raises(ApplicationError):
        asyncio.run(
            service.verify(
                OtpVerify(
                    phone_number=PHONE,
                    challenge_id=uuid.uuid4(),
                    code="123456",
                    privacy_notice_accepted=False,
                )
            )
        )
