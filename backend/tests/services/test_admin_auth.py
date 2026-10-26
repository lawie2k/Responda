import asyncio
import uuid
from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock

from pytest import mark, raises
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Environment, Settings
from app.core.exceptions import ApplicationError
from app.core.security import hash_password, hash_session_token, verify_password
from app.models import AuditLog, AuthSession, User
from app.services.admin_auth import AdminAuthService, AuthenticatedAdmin


def database_mock(*execute_results: MagicMock) -> MagicMock:
    database = MagicMock(spec=AsyncSession)
    database.execute = AsyncMock(side_effect=execute_results)
    database.commit = AsyncMock()
    database.refresh = AsyncMock()
    return database


def scalar_result(value: object) -> MagicMock:
    result = MagicMock()
    result.scalar_one_or_none.return_value = value
    return result


def active_sessions_result(sessions: list[AuthSession]) -> MagicMock:
    result = MagicMock()
    result.scalars.return_value = sessions
    return result


def joined_session_result(session: AuthSession, user: User) -> MagicMock:
    result = MagicMock()
    result.one_or_none.return_value = (session, user)
    return result


@mark.parametrize("role", ["admin", "operations_admin"])
def test_administrator_login_creates_only_a_hashed_session_token(role: str) -> None:
    user = User(
        user_id=uuid.uuid4(),
        full_name="Test Admin",
        email="admin@example.com",
        password_hash=hash_password("correct-long-password"),
        role=role,
        is_active=True,
    )
    database = database_mock(scalar_result(user), active_sessions_result([]))
    settings = Settings(environment=Environment.TESTING, debug=False, _env_file=None)
    service = AdminAuthService(database, settings)

    result = asyncio.run(
        service.login(
            email=" ADMIN@example.com ",
            password="correct-long-password",
            ip_address="127.0.0.1",
            device_name="test client",
        )
    )

    added_objects = [call.args[0] for call in database.add.call_args_list]
    stored_session = next(item for item in added_objects if isinstance(item, AuthSession))
    audit = next(item for item in added_objects if isinstance(item, AuditLog))
    user_lookup = database.execute.await_args_list[0].args[0]
    assert stored_session.refresh_token_hash == hash_session_token(result.token)
    assert stored_session.refresh_token_hash != result.token
    assert audit.action == "auth.login.succeeded"
    assert "users.deleted_at IS NULL" in str(user_lookup)
    assert "FOR UPDATE" in str(user_lookup)
    database.commit.assert_awaited_once()


@mark.parametrize("role", ["dispatcher", "verifier", "viewer", "reporter"])
def test_non_administrator_role_cannot_open_a_dashboard_session(role: str) -> None:
    user = User(
        user_id=uuid.uuid4(),
        full_name="Non-admin Staff",
        email="staff@example.com",
        password_hash=hash_password("correct-long-password"),
        role=role,
        is_active=True,
    )
    database = database_mock(scalar_result(user))
    settings = Settings(environment=Environment.TESTING, debug=False, _env_file=None)
    service = AdminAuthService(database, settings)

    with raises(ApplicationError) as error:
        asyncio.run(
            service.login(
                email="staff@example.com",
                password="correct-long-password",
                ip_address="127.0.0.1",
                device_name=None,
            )
        )

    assert error.value.code == "staff_access_required"
    assert not any(isinstance(call.args[0], AuthSession) for call in database.add.call_args_list)
    audit = database.add.call_args.args[0]
    assert isinstance(audit, AuditLog)
    assert audit.action == "auth.login.rejected"


def test_existing_session_is_rejected_after_role_loses_dashboard_access() -> None:
    user = User(
        user_id=uuid.uuid4(),
        full_name="Former Dashboard Staff",
        email="former@example.com",
        password_hash="not-used",
        role="dispatcher",
        is_active=True,
    )
    session = AuthSession(
        session_id=uuid.uuid4(),
        user_id=user.user_id,
        refresh_token_hash=hash_session_token("existing-token"),
        expires_at=datetime.now(UTC) + timedelta(hours=1),
    )
    database = database_mock(joined_session_result(session, user))
    settings = Settings(environment=Environment.TESTING, debug=False, _env_file=None)
    service = AdminAuthService(database, settings)

    with raises(ApplicationError) as error:
        asyncio.run(service.authenticate("existing-token"))

    assert error.value.code == "invalid_session"


def test_service_uses_a_generic_error_for_unknown_email() -> None:
    database = database_mock(scalar_result(None))
    settings = Settings(environment=Environment.TESTING, debug=False, _env_file=None)
    service = AdminAuthService(database, settings)

    with raises(ApplicationError) as error:
        asyncio.run(
            service.login(
                email="missing@example.com",
                password="candidate-password",
                ip_address="127.0.0.1",
                device_name=None,
            )
        )

    assert error.value.code == "invalid_credentials"
    assert error.value.message == "Invalid email or password."
    added_audit = database.add.call_args.args[0]
    assert isinstance(added_audit, AuditLog)
    assert added_audit.actor_user_id is None
    database.commit.assert_awaited_once()


def password_context(role: str = "admin") -> AuthenticatedAdmin:
    user = User(
        user_id=uuid.uuid4(),
        full_name="Test Admin",
        email="admin@example.com",
        password_hash=hash_password("current-test-password"),
        role=role,
        is_active=True,
    )
    session = AuthSession(
        session_id=uuid.uuid4(),
        user_id=user.user_id,
        refresh_token_hash=hash_session_token("old-test-token"),
        expires_at=datetime.now(UTC) + timedelta(hours=1),
    )
    return AuthenticatedAdmin(user=user, session=session)


@mark.parametrize("role", ["admin", "operations_admin"])
def test_password_change_rotates_current_token_and_revokes_other_sessions(role: str) -> None:
    context = password_context(role)
    other = AuthSession(session_id=uuid.uuid4(), user_id=context.user.user_id)
    database = database_mock(
        scalar_result(context.user),
        scalar_result(context.session),
        active_sessions_result([other]),
    )
    service = AdminAuthService(database, Settings(_env_file=None))
    expires_at = context.session.expires_at

    result = asyncio.run(
        service.change_password(
            context,
            current_password="current-test-password",
            new_password="new-test-password",
            ip_address="127.0.0.1",
        )
    )

    assert verify_password("new-test-password", context.user.password_hash)
    assert not verify_password("current-test-password", context.user.password_hash)
    assert context.session.refresh_token_hash == hash_session_token(result.token)
    assert context.session.refresh_token_hash != hash_session_token("old-test-token")
    assert context.session.revoked_at is None
    assert context.session.expires_at == expires_at
    assert other.revoked_at is not None
    statements = [call.args[0] for call in database.execute.await_args_list]
    assert all("FOR UPDATE" in str(statement) for statement in statements)
    assert statements[1].compile().params["refresh_token_hash_1"] == hash_session_token(
        "old-test-token",
    )
    assert "auth_sessions.user_id" in str(statements[2])
    assert "auth_sessions.session_id !=" in str(statements[2])
    audit = database.add.call_args.args[0]
    assert isinstance(audit, AuditLog)
    assert audit.action == "auth.password_change.succeeded"
    assert audit.actor_user_id == context.user.user_id
    assert audit.details == '{"result": "success"}'
    database.commit.assert_awaited_once()


def test_incorrect_current_password_is_rejected_without_mutation() -> None:
    context = password_context()
    old_hash = context.user.password_hash
    token_hash = context.session.refresh_token_hash
    database = database_mock(scalar_result(context.user), scalar_result(context.session))
    service = AdminAuthService(database, Settings(_env_file=None))

    with raises(ApplicationError) as caught:
        asyncio.run(
            service.change_password(
                context,
                current_password="incorrect-test-password",
                new_password="new-test-password",
                ip_address="127.0.0.1",
            )
        )

    assert caught.value.code == "current_password_invalid"
    assert caught.value.status_code == 400
    assert context.user.password_hash == old_hash
    assert context.session.refresh_token_hash == token_hash
    assert database.execute.await_count == 2
    assert database.add.call_args.args[0].action == "auth.password_change.failed"


def test_password_change_rejects_reusing_the_current_password() -> None:
    context = password_context()
    database = database_mock(scalar_result(context.user), scalar_result(context.session))
    service = AdminAuthService(database, Settings(_env_file=None))
    with raises(ApplicationError) as caught:
        asyncio.run(
            service.change_password(
                context,
                current_password="current-test-password",
                new_password="current-test-password",
                ip_address="127.0.0.1",
            )
        )
    assert caught.value.code == "password_unchanged"
    database.commit.assert_not_awaited()


@mark.parametrize("state", ["missing", "inactive", "deleted", "role"])
def test_password_change_rechecks_the_account_under_lock(state: str) -> None:
    context = password_context()
    if state == "inactive":
        context.user.is_active = False
    elif state == "deleted":
        context.user.deleted_at = datetime.now(UTC)
    elif state == "role":
        context.user.role = "reporter"
    database = database_mock(scalar_result(None if state == "missing" else context.user))
    service = AdminAuthService(database, Settings(_env_file=None))
    with raises(ApplicationError) as caught:
        asyncio.run(
            service.change_password(
                context,
                current_password="current-test-password",
                new_password="new-test-password",
                ip_address="127.0.0.1",
            )
        )
    assert caught.value.code == "invalid_session"
    database.commit.assert_not_awaited()


@mark.parametrize("state", ["missing_or_rotated", "revoked", "expired"])
def test_password_change_rechecks_current_session_before_password_verification(state: str) -> None:
    context = password_context()
    if state == "revoked":
        context.session.revoked_at = datetime.now(UTC)
    elif state == "expired":
        context.session.expires_at = datetime.now(UTC) - timedelta(seconds=1)
    database = database_mock(
        scalar_result(context.user),
        scalar_result(None if state == "missing_or_rotated" else context.session),
    )
    service = AdminAuthService(database, Settings(_env_file=None))
    with raises(ApplicationError) as caught:
        asyncio.run(
            service.change_password(
                context,
                current_password="current-test-password",
                new_password="new-test-password",
                ip_address="127.0.0.1",
            )
        )
    assert caught.value.code == "invalid_session"
    database.commit.assert_not_awaited()
