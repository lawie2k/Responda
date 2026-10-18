import uuid
from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi.testclient import TestClient

from app.api.dependencies import get_admin_auth_service
from app.api.v1.admin.mobile_accounts import get_mobile_account_service
from app.core.config import Settings
from app.core.exceptions import ApplicationError
from app.main import create_app
from app.models import AuthSession, User
from app.schemas.admin_mobile_accounts import MobileAccountCounts, MobileAccountList
from app.services.admin_auth import AuthenticatedAdmin

STAMP = datetime.now(UTC)


def client_for(role="admin", signed_in=True):
    app = create_app(Settings(_env_file=None, environment="testing"))
    user = User(user_id=uuid.uuid4(), role=role, full_name="Synthetic", is_active=True)
    context = AuthenticatedAdmin(
        user,
        AuthSession(
            session_id=uuid.uuid4(),
            user_id=user.user_id,
            refresh_token_hash="synthetic",
            expires_at=STAMP + timedelta(hours=1),
        ),
    )

    async def authenticate(token):
        if not signed_in:
            raise ApplicationError("Sign in.", status_code=401)
        return context

    auth = MagicMock()
    auth.authenticate = AsyncMock(side_effect=authenticate)
    service = MagicMock()
    service.list_accounts = AsyncMock(
        return_value=MobileAccountList(
            items=[],
            total=0,
            page=1,
            page_size=10,
            total_pages=0,
            counts=MobileAccountCounts(total=0, active=0, suspended=0),
        )
    )
    service.update_status = AsyncMock(
        side_effect=ApplicationError("Stale account.", status_code=409)
    )
    app.dependency_overrides[get_admin_auth_service] = lambda: auth
    app.dependency_overrides[get_mobile_account_service] = lambda: service
    return TestClient(app), service


@pytest.mark.parametrize(
    "role,expected", [("admin", 200), ("operations_admin", 200), ("reporter", 403)]
)
def test_role_restricted_reads_and_no_store(role, expected):
    client, _ = client_for(role)
    with client:
        response = client.get("/api/v1/admin/mobile-accounts")
    assert response.status_code == expected and response.headers["cache-control"] == "no-store"


def test_anonymous_read_rejected():
    client, _ = client_for(signed_in=False)
    with client:
        assert client.get("/api/v1/admin/mobile-accounts").status_code == 401


@pytest.mark.parametrize("query", ["page=0", "page_size=101", "active=invalid", "search=" * 1])
def test_bounded_queries(query):
    client, service = client_for()
    with client:
        response = client.get("/api/v1/admin/mobile-accounts?" + query)
    assert response.status_code == 422
    service.list_accounts.assert_not_awaited()


@pytest.mark.parametrize(
    "role,origin,expected",
    [
        ("admin", "http://localhost:5173", 409),
        ("operations_admin", "http://localhost:5173", 403),
        ("admin", "https://untrusted.test", 403),
    ],
)
def test_writes_require_super_admin_trusted_origin_and_current_version(role, origin, expected):
    client, service = client_for(role)
    with client:
        response = client.patch(
            f"/api/v1/admin/mobile-accounts/{uuid.uuid4()}/status",
            json={
                "expected_updated_at": STAMP.isoformat(),
                "is_active": False,
                "reason": "suspected_misuse",
            },
            headers={"Origin": origin},
        )
    assert response.status_code == expected
    if expected == 403:
        service.update_status.assert_not_awaited()


def test_arbitrary_notes_and_role_overrides_rejected_without_echo():
    client, service = client_for()
    with client:
        response = client.patch(
            f"/api/v1/admin/mobile-accounts/{uuid.uuid4()}/status",
            json={
                "expected_updated_at": STAMP.isoformat(),
                "is_active": False,
                "reason": "sensitive free text",
                "role": "admin",
            },
        )
    assert response.status_code == 422 and "sensitive free text" not in response.text
    service.update_status.assert_not_awaited()
