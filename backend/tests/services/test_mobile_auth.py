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
from app.schemas.mobile_auth import BetaRegistration, MobileProfileUpdate, OtpVerify
from app.schemas.mobile_reports import MobileReportCreateRequest
from app.services.mobile_auth import MobileAuthService
from app.services.mobile_reports import MobileReportService

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
        database.add_all.side_effect = db.add_all
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


def test_beta_session_submits_report_without_claiming_phone_verification(mobile_database):
    from app.models import IncidentType, Report

    service, db = mobile_database
    service.settings.mobile_beta_accounts_enabled = True
    db.add(IncidentType(code="fire", name="Fire", default_priority="high", active=True))
    db.commit()

    async def exercise():
        result = await service.register_beta(
            BetaRegistration(
                full_name="Synthetic beta tester",
                barangay="Kingking",
                privacy_notice_accepted=True,
            )
        )
        assert result.access_token.startswith("mobile_beta_")
        assert result.user.phone_number is None
        assert result.user.phone_verified_at is None
        assert db.scalar(select(OtpChallenge)) is None
        reporter, session = await service.authenticate(result.access_token)
        assert session.refresh_token_hash == hash_session_token(result.access_token)
        receipt = await MobileReportService(service.db).create_report(
            reporter=reporter,
            payload=MobileReportCreateRequest(
                client_report_id=uuid.uuid4(),
                incident_type_code="fire",
                description="Synthetic beta report for automated verification.",
                landmark="Synthetic test area",
            ),
        )
        assert db.get(Report, receipt.report_id).reporter_id == reporter.user_id
        assert (await service.profile(result.access_token)).user.full_name == result.user.full_name
        await service.logout(result.access_token)
        with pytest.raises(ApplicationError):
            await service.profile(result.access_token)

    asyncio.run(exercise())


@pytest.mark.parametrize(
    "state", ["disabled", "staging", "inactive", "deleted", "verified", "revoked"]
)
def test_beta_session_fails_closed_when_disabled_or_identity_changes(mobile_database, state):
    service, db = mobile_database
    service.settings.mobile_beta_accounts_enabled = True

    async def exercise():
        result = await service.register_beta(BetaRegistration(privacy_notice_accepted=True))
        user = db.scalar(select(User))
        if state == "disabled":
            service.settings.mobile_beta_accounts_enabled = False
        elif state == "staging":
            service.settings.environment = "staging"
        elif state == "inactive":
            user.is_active = False
        elif state == "deleted":
            user.deleted_at = datetime.now(UTC)
        elif state == "verified":
            user.phone_number = PHONE
            user.phone_verified_at = datetime.now(UTC)
        elif state == "revoked":
            db.scalar(select(AuthSession)).revoked_at = datetime.now(UTC)
        db.commit()
        with pytest.raises(ApplicationError):
            await service.authenticate(result.access_token)

    asyncio.run(exercise())


def test_beta_registration_requires_server_flag_and_consent(mobile_database):
    service, db = mobile_database

    async def exercise():
        with pytest.raises(ApplicationError) as error:
            await service.register_beta(BetaRegistration(privacy_notice_accepted=True))
        assert error.value.status_code == 403
        service.settings.mobile_beta_accounts_enabled = True
        with pytest.raises(ApplicationError) as error:
            await service.register_beta(BetaRegistration(privacy_notice_accepted=False))
        assert error.value.code == "privacy_required"
        assert db.scalar(select(User)) is None

    asyncio.run(exercise())


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
