import uuid
from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi.testclient import TestClient

from app.api.dependencies import get_admin_auth_service, get_admin_staff_service
from app.core.config import Environment, Settings
from app.core.exceptions import ApplicationError
from app.main import create_app
from app.models import AuthSession, User
from app.schemas.admin_staff import StaffItem, StaffList
from app.services.admin_auth import AuthenticatedAdmin
from app.services.admin_staff import AdminStaffService

ID = uuid.uuid4()
STAMP = datetime.now(UTC)
ITEM = StaffItem(
    user_id=ID,
    full_name="Synthetic admin",
    email="staff@example.com",
    role="operations_admin",
    is_active=True,
    created_at=STAMP,
    updated_at=STAMP,
)
CREATE = {"full_name": "Synthetic", "email": "new@example.com", "password": "synthetic-password"}
UPDATE = {
    "full_name": "Updated",
    "email": "staff@example.com",
    "is_active": False,
    "expected_updated_at": STAMP.isoformat(),
}
REVOKE = {"expected_updated_at": STAMP.isoformat()}
OPERATIONS = [
    ("GET", "", None),
    ("GET", "/policy", None),
    ("POST", "", CREATE),
    ("PATCH", f"/{ID}", UPDATE),
    ("POST", f"/{ID}/revoke-sessions", REVOKE),
]


def client_for(role="admin", signed_in=True):
    app = create_app(Settings(environment=Environment.TESTING, _env_file=None))
    service = MagicMock(spec=AdminStaffService)
    service.list_staff = AsyncMock(
        return_value=StaffList(items=[ITEM], total=1, page=1, page_size=10, total_pages=1)
    )
    for method in ("create_staff", "update_staff", "revoke_sessions"):
        setattr(service, method, AsyncMock(return_value=ITEM))

    async def authenticate(token):
        if token != "synthetic-session":
            raise ApplicationError("Session required.", code="invalid_session", status_code=401)
        user = User(user_id=uuid.uuid4(), full_name="Synthetic staff", role=role, is_active=True)
        return AuthenticatedAdmin(
            user,
            AuthSession(
                session_id=uuid.uuid4(),
                user_id=user.user_id,
                refresh_token_hash="not-returned",
                expires_at=STAMP + timedelta(hours=1),
            ),
        )

    auth = MagicMock()
    auth.authenticate = AsyncMock(side_effect=authenticate)
    app.dependency_overrides[get_admin_auth_service] = lambda: auth
    app.dependency_overrides[get_admin_staff_service] = lambda: service
    client = TestClient(app)
    if signed_in:
        client.cookies.set("responda_admin_session", "synthetic-session", path="/api/v1/admin")
    return client, service


@pytest.mark.parametrize("method,path,payload", OPERATIONS)
def test_super_admin_endpoints_use_no_store_and_return_safe_fields(method, path, payload):
    client, _ = client_for()
    with client:
        response = client.request(
            method,
            f"/api/v1/admin/staff{path}",
            json=payload,
            headers={"Origin": "http://localhost:5173"},
        )
    assert response.status_code in (200, 201)
    assert response.headers["cache-control"] == "no-store, max-age=0"
    assert "password_hash" not in response.text and "synthetic-password" not in response.text
    assert "refresh_token" not in response.text and "database_url" not in response.text


@pytest.mark.parametrize("method,path,payload", OPERATIONS)
@pytest.mark.parametrize(
    "role,signed_in,expected",
    [
        ("operations_admin", True, 403),
        ("reporter", True, 403),
        ("admin", False, 401),
    ],
)
def test_non_super_admins_cannot_read_or_write_staff(
    method, path, payload, role, signed_in, expected
):
    client, service = client_for(role, signed_in)
    with client:
        response = client.request(method, f"/api/v1/admin/staff{path}", json=payload)
    assert response.status_code == expected
    for action in ("list_staff", "create_staff", "update_staff", "revoke_sessions"):
        getattr(service, action).assert_not_awaited()


@pytest.mark.parametrize("method,path,payload", OPERATIONS[2:])
def test_untrusted_origin_rejected_for_staff_writes(method, path, payload):
    client, _ = client_for()
    with client:
        response = client.request(
            method,
            f"/api/v1/admin/staff{path}",
            json=payload,
            headers={"Origin": "https://untrusted.example"},
        )
    assert response.status_code == 403


@pytest.mark.parametrize(
    "payload",
    [
        {**CREATE, "password": "hidden"},
        {**CREATE, "full_name": " "},
        {**CREATE, "email": "invalid"},
        {**CREATE, "role": "admin"},
        {**CREATE, "is_active": True},
    ],
)
def test_staff_validation_rejects_weak_or_extra_fields_without_echoing_password(payload):
    client, service = client_for()
    with client:
        response = client.post("/api/v1/admin/staff", json=payload)
    assert response.status_code == 422
    assert payload["password"] not in response.text
    assert "input" not in response.json()
    service.create_staff.assert_not_awaited()


@pytest.mark.parametrize(
    "query", ["page=0", "page_size=101", "active=other", "search=" + "a" * 101]
)
def test_staff_list_caps_and_validates_filters(query):
    client, service = client_for()
    with client:
        response = client.get(f"/api/v1/admin/staff?{query}")
    assert response.status_code == 422
    service.list_staff.assert_not_awaited()
