import asyncio
import uuid
from unittest.mock import AsyncMock, MagicMock

from pytest import raises
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Environment, Settings
from app.core.exceptions import ApplicationError
from app.core.security import hash_password, hash_session_token
from app.models import AuditLog, AuthSession, User
from app.services.admin_auth import AdminAuthService


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


def test_service_creates_only_a_hashed_session_token() -> None:
    user = User(
        user_id=uuid.uuid4(),
        full_name="Test Admin",
        email="admin@example.com",
        password_hash=hash_password("correct-long-password"),
        role="admin",
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
    assert stored_session.refresh_token_hash == hash_session_token(result.token)
    assert stored_session.refresh_token_hash != result.token
    assert audit.action == "auth.login.succeeded"
    database.commit.assert_awaited_once()


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
