import uuid
from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient
from pytest import mark

from app.api.dependencies import get_admin_auth_service
from app.core.config import Environment, Settings
from app.core.exceptions import ApplicationError
from app.main import create_app
from app.models import AuthSession, User
from app.services.admin_auth import AdminLoginResult, AuthenticatedAdmin


class FakeAdminAuthService:
    def __init__(self) -> None:
        self.user = User(
            user_id=uuid.uuid4(),
            full_name="Test Operations Admin",
            email="operations@example.com",
            password_hash="not-returned",
            role="operations_admin",
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
        self.password_calls = 0

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
        if token != self.token:
            raise ApplicationError(
                "A valid staff session is required.", code="invalid_session", status_code=401
            )
        return AuthenticatedAdmin(user=self.user, session=self.session)

    async def change_password(
        self,
        context: AuthenticatedAdmin,
        *,
        current_password: str,
        new_password: str,
        ip_address: str,
    ) -> AdminLoginResult:
        assert context.user.user_id == self.user.user_id
        assert current_password == "current-test-password"
        assert new_password == "new-test-password"
        assert ip_address
        self.password_calls += 1
        self.token = "rotated-test-session-token"
        return AdminLoginResult(user=self.user, session=self.session, token=self.token)

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
            json={"email": "operations@example.com", "password": "a-password-value"},
            headers={"Origin": "http://localhost:5173"},
        )

    assert response.status_code == 200
    assert response.json()["user"] == {
        "user_id": str(service.user.user_id),
        "full_name": "Test Operations Admin",
        "email": "operations@example.com",
        "role": "operations_admin",
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
    assert response.json()["user"]["role"] == "operations_admin"
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
            json={"email": "operations@example.com", "password": "a-password-value"},
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
                json={"email": "operations@example.com", "password": "a-password-value"},
            )
            assert allowed.status_code == 200
        blocked = client.post(
            "/api/v1/admin/auth/login",
            json={"email": "operations@example.com", "password": "a-password-value"},
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


@mark.parametrize("role", ["admin", "operations_admin"])
def test_password_change_returns_a_rotated_private_cookie_for_both_admin_roles(role: str) -> None:
    service = FakeAdminAuthService()
    service.user.role = role
    with build_test_client(service) as client:
        client.cookies.set("responda_admin_session", service.token, path="/api/v1/admin")
        response = client.post(
            "/api/v1/admin/auth/change-password",
            json={
                "current_password": "current-test-password",
                "new_password": "new-test-password",
                "confirmation": "new-test-password",
            },
            headers={"Origin": "http://localhost:5173"},
        )
    assert response.status_code == 200
    assert service.password_calls == 1
    assert response.json()["user"]["role"] == role
    assert "rotated-test-session-token" in response.headers["set-cookie"]
    assert "HttpOnly" in response.headers["set-cookie"]
    assert "SameSite=lax" in response.headers["set-cookie"]
    assert "Path=/api/v1/admin" in response.headers["set-cookie"]
    assert "password" not in response.text and "token" not in response.text
    assert response.headers["cache-control"] == "no-store, max-age=0"


@mark.parametrize(
    "invalid",
    [
        {"new_password": "short"},
        {"confirmation": "different-test-password"},
        {"current_password": ""},
        {"new_password": "a" * 1025},
        {"target_user_id": "unrequested-account"},
    ],
)
def test_invalid_password_payload_never_echoes_credentials(invalid: dict[str, str]) -> None:
    service = FakeAdminAuthService()
    with build_test_client(service) as client:
        client.cookies.set("responda_admin_session", service.token, path="/api/v1/admin")
        response = client.post(
            "/api/v1/admin/auth/change-password",
            json={
                "current_password": "current-test-password",
                "new_password": "new-test-password",
                "confirmation": "new-test-password",
                **invalid,
            },
        )
    assert response.status_code == 422
    assert "current-test-password" not in response.text
    assert "new-test-password" not in response.text
    assert service.password_calls == 0
    assert response.headers["cache-control"] == "no-store, max-age=0"


def test_password_change_requires_a_session_and_trusted_origin() -> None:
    service = FakeAdminAuthService()
    payload = {
        "current_password": "current-test-password",
        "new_password": "new-test-password",
        "confirmation": "new-test-password",
    }
    with build_test_client(service) as client:
        unauthenticated = client.post("/api/v1/admin/auth/change-password", json=payload)
        assert unauthenticated.status_code == 401
        client.cookies.set("responda_admin_session", service.token, path="/api/v1/admin")
        untrusted = client.post(
            "/api/v1/admin/auth/change-password",
            json=payload,
            headers={"Origin": "https://attacker.example"},
        )
    assert untrusted.status_code == 403
    assert service.password_calls == 0


def test_password_change_has_a_separate_attempt_limit() -> None:
    service = FakeAdminAuthService()
    payload = {
        "current_password": "current-test-password",
        "new_password": "new-test-password",
        "confirmation": "new-test-password",
    }
    with build_test_client(service, rate_limit_attempts=2) as client:
        client.post(
            "/api/v1/admin/auth/login",
            json={
                "email": "operations@example.com",
                "password": "current-test-password",
            },
        )
        for _ in range(2):
            assert (
                client.post("/api/v1/admin/auth/change-password", json=payload).status_code == 200
            )
        response = client.post("/api/v1/admin/auth/change-password", json=payload)
    assert response.status_code == 429
    assert response.headers["retry-after"] == "60"
    assert service.password_calls == 2
