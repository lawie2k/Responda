import uuid
from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

from app.api.dependencies import get_admin_auth_service
from app.core.config import Environment, Settings
from app.main import create_app
from app.models import AuthSession, User
from app.services.admin_auth import AdminLoginResult, AuthenticatedAdmin


class FakeAdminAuthService:
    def __init__(self) -> None:
        self.user = User(
            user_id=uuid.uuid4(),
            full_name="Test Dispatcher",
            email="dispatcher@example.com",
            password_hash="not-returned",
            role="dispatcher",
            is_active=True,
        )
        self.session = AuthSession(
            session_id=uuid.uuid4(),
            user_id=self.user.user_id,
            refresh_token_hash="stored-hash-only",
            expires_at=datetime.now(UTC) + timedelta(hours=8),
        )
        self.token = "opaque-test-session-token"
        self.login_calls = 0
        self.logout_calls = 0

    async def login(
        self,
        *,
        email: str,
        password: str,
        ip_address: str,
        device_name: str | None,
    ) -> AdminLoginResult:
        del email, password, ip_address, device_name
        self.login_calls += 1
        return AdminLoginResult(user=self.user, session=self.session, token=self.token)

    async def authenticate(self, token: str | None) -> AuthenticatedAdmin:
        assert token == self.token
        return AuthenticatedAdmin(user=self.user, session=self.session)

    async def logout(self, context: AuthenticatedAdmin, *, ip_address: str) -> None:
        del context, ip_address
        self.logout_calls += 1


def build_test_client(
    service: FakeAdminAuthService,
    *,
    rate_limit_attempts: int = 5,
) -> TestClient:
    settings = Settings(
        environment=Environment.TESTING,
        debug=False,
        allowed_origins=["http://localhost:5173"],
        admin_login_rate_limit_attempts=rate_limit_attempts,
        _env_file=None,
    )
    application = create_app(settings)
    application.dependency_overrides[get_admin_auth_service] = lambda: service
    return TestClient(application)


def test_login_sets_http_only_cookie_without_returning_token() -> None:
    service = FakeAdminAuthService()

    with build_test_client(service) as client:
        response = client.post(
            "/api/v1/admin/auth/login",
            json={"email": "dispatcher@example.com", "password": "a-password-value"},
            headers={"Origin": "http://localhost:5173"},
        )

    assert response.status_code == 200
    assert response.json()["user"] == {
        "user_id": str(service.user.user_id),
        "full_name": "Test Dispatcher",
        "email": "dispatcher@example.com",
        "role": "dispatcher",
    }
    assert "token" not in response.text
    cookie = response.headers["set-cookie"]
    assert "responda_admin_session=opaque-test-session-token" in cookie
    assert "HttpOnly" in cookie
    assert "SameSite=lax" in cookie
    assert "Path=/api/v1/admin" in cookie
    assert response.headers["cache-control"] == "no-store, max-age=0"


def test_current_session_uses_the_http_only_cookie() -> None:
    service = FakeAdminAuthService()

    with build_test_client(service) as client:
        client.cookies.set("responda_admin_session", service.token, path="/api/v1/admin")
        response = client.get("/api/v1/admin/auth/me")

    assert response.status_code == 200
    assert response.json()["user"]["role"] == "dispatcher"
    assert response.headers["cache-control"] == "no-store, max-age=0"


def test_logout_revokes_the_session_and_expires_the_cookie() -> None:
    service = FakeAdminAuthService()

    with build_test_client(service) as client:
        client.cookies.set("responda_admin_session", service.token, path="/api/v1/admin")
        response = client.post(
            "/api/v1/admin/auth/logout",
            headers={"Origin": "http://localhost:5173"},
        )

    assert response.status_code == 204
    assert service.logout_calls == 1
    assert "responda_admin_session=" in response.headers["set-cookie"]
    assert "Max-Age=0" in response.headers["set-cookie"]
    assert response.headers["cache-control"] == "no-store, max-age=0"


def test_untrusted_browser_origin_is_rejected() -> None:
    service = FakeAdminAuthService()

    with build_test_client(service) as client:
        response = client.post(
            "/api/v1/admin/auth/login",
            json={"email": "dispatcher@example.com", "password": "a-password-value"},
            headers={"Origin": "https://attacker.example"},
        )

    assert response.status_code == 403
    assert response.json()["error"]["code"] == "origin_not_allowed"
    assert service.login_calls == 0


def test_login_is_rate_limited_before_password_verification() -> None:
    service = FakeAdminAuthService()

    with build_test_client(service, rate_limit_attempts=2) as client:
        for _ in range(2):
            allowed = client.post(
                "/api/v1/admin/auth/login",
                json={"email": "dispatcher@example.com", "password": "a-password-value"},
            )
            assert allowed.status_code == 200
        blocked = client.post(
            "/api/v1/admin/auth/login",
            json={"email": "dispatcher@example.com", "password": "a-password-value"},
        )

    assert blocked.status_code == 429
    assert blocked.json()["error"]["code"] == "login_rate_limited"
    assert blocked.headers["retry-after"] == "60"
    assert service.login_calls == 2


def test_invalid_login_payload_is_rejected() -> None:
    service = FakeAdminAuthService()

    with build_test_client(service) as client:
        response = client.post(
            "/api/v1/admin/auth/login",
            json={"email": "not-an-email", "password": "value"},
        )

    assert response.status_code == 422
    assert service.login_calls == 0
