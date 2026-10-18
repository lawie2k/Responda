import asyncio
import json
import uuid
from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock

import pytest
from sqlalchemy import create_engine, event, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session

from app.core.exceptions import ApplicationError
from app.db.base import Base
from app.models import AuditLog, AuthSession, IncidentType, Report, User
from app.schemas.admin_mobile_accounts import MobileAccountStatusUpdate
from app.services.admin_auth import AuthenticatedAdmin
from app.services.admin_mobile_accounts import AdminMobileAccountService


@pytest.fixture
def accounts():
    engine = create_engine("sqlite://")

    @event.listens_for(engine, "connect")
    def setup(connection, _):
        connection.create_function("gen_random_uuid", 0, lambda: uuid.uuid4().hex)

    Base.metadata.create_all(engine)
    with Session(engine, expire_on_commit=False) as db:
        now = datetime.now(UTC)
        actor = User(
            user_id=uuid.uuid4(),
            full_name="Synthetic super",
            email="super@example.com",
            role="admin",
            is_active=True,
            updated_at=now,
        )
        citizen = User(
            user_id=uuid.uuid4(),
            full_name="Synthetic citizen",
            phone_number="+639000000001",
            role="reporter",
            is_active=True,
            barangay="Kingking",
            phone_verified_at=now,
            privacy_notice_accepted_at=now,
            updated_at=now,
        )
        db.add_all([actor, citizen])
        db.flush()
        actor_session = AuthSession(
            session_id=uuid.uuid4(),
            user_id=actor.user_id,
            refresh_token_hash="actor-hash",
            expires_at=now + timedelta(hours=1),
        )
        citizen_session = AuthSession(
            session_id=uuid.uuid4(),
            user_id=citizen.user_id,
            refresh_token_hash="citizen-hash",
            expires_at=now + timedelta(days=1),
            created_at=now,
        )
        db.add_all([actor_session, citizen_session])
        db.commit()
        database = MagicMock(spec=AsyncSession)
        for method in ("execute", "scalar", "scalars", "flush", "commit", "rollback"):
            setattr(database, method, AsyncMock(side_effect=getattr(db, method)))
        database.add.side_effect = db.add
        yield (
            AdminMobileAccountService(database),
            db,
            AuthenticatedAdmin(actor, actor_session),
            citizen,
        )
    engine.dispose()


def payload(user, active=False, **overrides):
    return MobileAccountStatusUpdate(
        expected_updated_at=overrides.get("expected", user.updated_at),
        is_active=active,
        reason=overrides.get("reason", "review_completed" if active else "suspected_misuse"),
    )


def listing(service, current, **kwargs):
    return asyncio.run(
        service.list_accounts(
            current,
            page=kwargs.get("page", 1),
            page_size=kwargs.get("page_size", 10),
            search=kwargs.get("search"),
            active=kwargs.get("active"),
        )
    )


def test_real_accounts_only_masking_and_empty_pagination(accounts):
    service, db, current, citizen = accounts
    now = datetime.now(UTC)
    for index, changes in enumerate(
        [
            {},
            {"phone_verified_at": now},
            {"phone_verified_at": now, "privacy_notice_accepted_at": now, "deleted_at": now},
        ]
    ):
        db.add(
            User(
                user_id=uuid.uuid4(),
                full_name="Manual caller",
                role="reporter",
                phone_number=f"+63900000000{index + 2}",
                **changes,
            )
        )
    db.commit()
    result = listing(service, current)
    assert result.total == result.counts.total == result.counts.active == 1
    item = result.items[0]
    assert item.user_id == citizen.user_id
    assert citizen.phone_number not in result.model_dump_json()
    assert item.masked_phone.endswith("0001") and item.last_sign_in_at is not None
    assert "refresh_token_hash" not in result.model_dump_json()
    assert listing(service, current, page=2, page_size=1).items == []


@pytest.mark.parametrize(
    "search,expected",
    [
        ("Synthetic", 1),
        ("Kingking", 1),
        ("09000000001", 1),
        ("+639000000001", 1),
        ("%", 0),
        ("_", 0),
        ("missing", 0),
    ],
)
def test_search_escapes_wildcards_and_supports_exact_phone(accounts, search, expected):
    service, _, current, _ = accounts
    assert listing(service, current, search=search).total == expected


def test_report_counts_exclude_manual_and_deleted_without_join_multiplication(accounts):
    service, db, current, user = accounts
    kind = IncidentType(
        incident_type_id=uuid.uuid4(),
        code="synthetic",
        name="Synthetic",
        default_priority="low",
        active=True,
    )
    db.add(kind)
    db.flush()
    for source, deleted in [("app_api", False), ("manual", False), ("app_sms", True)]:
        db.add(
            Report(
                report_id=uuid.uuid4(),
                client_report_id=uuid.uuid4(),
                reporter_id=user.user_id,
                incident_type_id=kind.incident_type_id,
                source=source,
                description_original="Synthetic",
                deleted_at=datetime.now(UTC) if deleted else None,
            )
        )
    db.commit()
    assert listing(service, current).items[0].reports_submitted == 1


def test_suspend_restore_revoke_sessions_and_minimize_audits(accounts):
    service, db, current, user = accounts
    asyncio.run(service.update_status(current, user.user_id, payload(user)))
    assert not user.is_active
    session = db.scalar(select(AuthSession).where(AuthSession.user_id == user.user_id))
    assert session.revoked_at is not None
    assert listing(service, current, active=True).items == []
    result = listing(service, current, active=False)
    assert result.counts.suspended == result.total == 1
    asyncio.run(service.update_status(current, user.user_id, payload(user, True)))
    assert user.is_active and session.revoked_at is not None
    audits = db.scalars(select(AuditLog)).all()
    assert len(audits) == 2
    assert json.loads(audits[0].details) == {"reason": "suspected_misuse"}
    assert user.phone_number not in str([a.details for a in audits])


@pytest.mark.parametrize(
    "failure,code",
    [
        ("stale", 409),
        ("same", 409),
        ("reason", 422),
        ("missing", 404),
        ("staff", 404),
        ("manual", 404),
        ("deleted", 404),
    ],
)
def test_invalid_updates_do_not_mutate(accounts, failure, code):
    service, db, current, user = accounts
    target = user.user_id
    values = {}
    if failure == "stale":
        values["expected"] = datetime.now(UTC) - timedelta(days=1)
    if failure == "reason":
        values["reason"] = "review_completed"
    if failure == "same":
        values["active"] = True
    if failure == "missing":
        target = uuid.uuid4()
    if failure == "staff":
        target = current.user.user_id
    if failure == "manual":
        user.phone_verified_at = None
    if failure == "deleted":
        user.deleted_at = datetime.now(UTC)
    db.commit()
    with pytest.raises(ApplicationError) as caught:
        asyncio.run(service.update_status(current, target, payload(user, **values)))
    assert caught.value.status_code == code
    assert user.is_active and db.scalar(select(AuditLog)) is None


@pytest.mark.parametrize("failure", ["normal_admin", "inactive", "deleted", "revoked", "expired"])
def test_mutation_rechecks_actor_and_session(accounts, failure):
    service, db, current, user = accounts
    if failure == "normal_admin":
        current.user.role = "operations_admin"
    if failure == "inactive":
        current.user.is_active = False
    if failure == "deleted":
        current.user.deleted_at = datetime.now(UTC)
    if failure == "revoked":
        current.session.revoked_at = datetime.now(UTC)
    if failure == "expired":
        current.session.expires_at = datetime.now(UTC) - timedelta(days=1)
    db.commit()
    with pytest.raises(ApplicationError) as caught:
        asyncio.run(service.update_status(current, user.user_id, payload(user)))
    assert caught.value.status_code == 403 and user.is_active
