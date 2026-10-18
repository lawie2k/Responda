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
from app.core.security import verify_password
from app.db.base import Base
from app.models import AuditLog, AuthSession, User
from app.schemas.admin_staff import StaffCreate, StaffRevoke, StaffUpdate
from app.services.admin_auth import AuthenticatedAdmin
from app.services.admin_staff import AdminStaffService


@pytest.fixture
def staff_database():
    engine = create_engine("sqlite://")

    @event.listens_for(engine, "connect")
    def register_uuid(connection, _):
        connection.create_function("gen_random_uuid", 0, lambda: uuid.uuid4().hex)

    Base.metadata.create_all(engine)
    with Session(engine, expire_on_commit=False) as session:
        now = datetime.now(UTC)
        actor = User(
            user_id=uuid.uuid4(),
            full_name="Synthetic super",
            email="super@example.com",
            role="admin",
            is_active=True,
            updated_at=now,
        )
        target = User(
            user_id=uuid.uuid4(),
            full_name="Synthetic administrator",
            email="staff@example.com",
            role="operations_admin",
            is_active=True,
            updated_at=now,
        )
        current_session = AuthSession(
            session_id=uuid.uuid4(),
            user_id=actor.user_id,
            refresh_token_hash="synthetic-super-session",
            expires_at=now + timedelta(hours=1),
        )
        target_session = AuthSession(
            session_id=uuid.uuid4(),
            user_id=target.user_id,
            refresh_token_hash="synthetic-staff-session",
            expires_at=now + timedelta(hours=1),
        )
        session.add_all([actor, target, current_session, target_session])
        session.commit()
        database = MagicMock(spec=AsyncSession)
        database.execute = AsyncMock(side_effect=session.execute)
        database.add.side_effect = session.add
        database.flush = AsyncMock(side_effect=session.flush)
        database.commit = AsyncMock(side_effect=session.commit)
        database.rollback = AsyncMock(side_effect=session.rollback)
        yield (
            AdminStaffService(database),
            session,
            AuthenticatedAdmin(actor, current_session),
            target,
        )
    engine.dispose()


def update_payload(target, **changes):
    return StaffUpdate(
        full_name=changes.get("full_name", target.full_name),
        email=changes.get("email", target.email),
        is_active=changes.get("is_active", target.is_active),
        expected_updated_at=changes.get("expected_updated_at", target.updated_at),
    )


def test_create_hashes_password_and_audits_only_field_names(staff_database):
    service, session, current, _ = staff_database
    result = asyncio.run(
        service.create_staff(
            current,
            StaffCreate(
                full_name="  New synthetic admin  ",
                email=" NEW@example.com ",
                password="synthetic-password-42",
            ),
        )
    )
    stored = session.get(User, result.user_id)
    assert stored.role == "operations_admin" and stored.is_active
    assert stored.email == "new@example.com" and stored.full_name == "New synthetic admin"
    assert verify_password("synthetic-password-42", stored.password_hash)
    assert "password" not in result.model_dump_json()
    audit = session.scalar(select(AuditLog))
    assert json.loads(audit.details) == {"changed_fields": ["full_name", "email"]}
    assert "synthetic-password" not in audit.details and "example.com" not in audit.details


@pytest.mark.parametrize("change", [{"email": "new@example.com"}, {"is_active": False}])
def test_identity_or_activation_changes_revoke_sessions_atomically(staff_database, change):
    service, session, current, target = staff_database
    result = asyncio.run(
        service.update_staff(current, target.user_id, update_payload(target, **change))
    )
    old_session = session.scalar(select(AuthSession).where(AuthSession.user_id == target.user_id))
    assert old_session.revoked_at is not None
    assert result.updated_at != current.user.updated_at
    audit = session.scalar(select(AuditLog))
    assert json.loads(audit.details)["changed_fields"] == list(change)


def test_name_only_edit_keeps_sessions_and_can_reactivate(staff_database):
    service, session, current, target = staff_database
    asyncio.run(
        service.update_staff(
            current, target.user_id, update_payload(target, full_name="Updated synthetic staff")
        )
    )
    old_session = session.scalar(select(AuthSession).where(AuthSession.user_id == target.user_id))
    assert old_session.revoked_at is None
    target.is_active = False
    session.commit()
    result = asyncio.run(
        service.update_staff(current, target.user_id, update_payload(target, is_active=True))
    )
    assert result.is_active


@pytest.mark.parametrize("operation", ["update", "revoke"])
def test_super_admin_accounts_cannot_be_mutated(staff_database, operation):
    service, _, current, _ = staff_database
    with pytest.raises(ApplicationError) as error:
        if operation == "update":
            asyncio.run(
                service.update_staff(
                    current, current.user.user_id, update_payload(current.user, is_active=False)
                )
            )
        else:
            asyncio.run(
                service.revoke_sessions(
                    current,
                    current.user.user_id,
                    StaffRevoke(expected_updated_at=current.user.updated_at),
                )
            )
    assert error.value.code == "protected_staff_account"


def test_revocation_invalidates_old_version_and_prevents_stale_edit(staff_database):
    service, session, current, target = staff_database
    stale = update_payload(target, full_name="Stale edit")
    asyncio.run(
        service.revoke_sessions(
            current, target.user_id, StaffRevoke(expected_updated_at=target.updated_at)
        )
    )
    assert session.scalar(
        select(AuthSession).where(AuthSession.user_id == target.user_id)
    ).revoked_at
    with pytest.raises(ApplicationError) as error:
        asyncio.run(service.update_staff(current, target.user_id, stale))
    assert error.value.code == "staff_update_conflict"


@pytest.mark.parametrize("condition", ["inactive", "deleted", "role", "revoked", "expired"])
def test_actor_is_rechecked_inside_the_write_transaction(staff_database, condition):
    service, session, current, _ = staff_database
    if condition == "inactive":
        current.user.is_active = False
    elif condition == "deleted":
        current.user.deleted_at = datetime.now(UTC)
    elif condition == "role":
        current.user.role = "operations_admin"
    elif condition == "revoked":
        current.session.revoked_at = datetime.now(UTC)
    else:
        current.session.expires_at = datetime.now(UTC) - timedelta(seconds=1)
    session.commit()
    with pytest.raises(ApplicationError) as error:
        asyncio.run(
            service.create_staff(
                current,
                StaffCreate(
                    full_name="Blocked", email="blocked@example.com", password="synthetic-password"
                ),
            )
        )
    assert error.value.code == "staff_management_forbidden"
    assert session.scalar(select(AuditLog)) is None


def test_reserved_deleted_email_and_commit_conflicts_rollback(staff_database):
    service, session, current, target = staff_database
    target.deleted_at = datetime.now(UTC)
    session.commit()
    payload = StaffCreate(
        full_name="Duplicate", email="STAFF@example.com", password="synthetic-pass"
    )
    with pytest.raises(ApplicationError) as error:
        asyncio.run(service.create_staff(current, payload))
    assert error.value.code == "staff_email_conflict"
    # Simulate a competing writer winning after the availability check.
    service._email_available = AsyncMock()
    with pytest.raises(ApplicationError) as error:
        asyncio.run(service.create_staff(current, payload))
    assert error.value.code == "staff_write_conflict"
    assert session.scalar(select(AuditLog)) is None


def test_list_filters_pagination_and_private_field_exclusion(staff_database):
    service, session, _, target = staff_database
    session.add(User(full_name="Citizen", email="citizen@example.com", role="reporter"))
    session.commit()
    data = asyncio.run(service.list_staff(page=1, page_size=1, search=None, active=True))
    assert data.total == 2 and data.total_pages == 2 and len(data.items) == 1
    data = asyncio.run(service.list_staff(page=1, page_size=10, search="staff@", active=True))
    assert data.total == 1 and data.items[0].user_id == target.user_id
    assert (
        "password_hash" not in data.model_dump_json()
        and "refresh_token" not in data.model_dump_json()
    )
    assert asyncio.run(service.list_staff(page=1, page_size=10, search="%", active=None)).total == 0
    target.deleted_at = datetime.now(UTC)
    session.commit()
    assert (
        asyncio.run(service.list_staff(page=1, page_size=10, search=None, active=None)).total == 1
    )
