import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.api.v1.mobile.auth import service
from app.core.config import Settings
from app.core.exceptions import ApplicationError
from app.main import create_app


@pytest.fixture
def client():
    app = create_app(Settings(_env_file=None, environment="testing"))
    auth = MagicMock()
    auth.request_code = AsyncMock(side_effect=ApplicationError("Not configured.", status_code=503))
    auth.profile = AsyncMock(side_effect=ApplicationError("Sign in.", status_code=401))
    app.dependency_overrides[service] = lambda: auth
    with TestClient(app) as client:
        yield client, auth


def test_requests_fail_closed_when_delivery_unconfigured(client):
    client, _ = client
    response = client.post(
        "/api/v1/mobile/auth/otp/request", json={"phone_number": "+639000000001"}
    )
    assert response.status_code == 503 and response.headers["cache-control"] == "no-store"


def test_validation_does_not_echo_codes_or_phone(client):
    client, _ = client
    response = client.post(
        "/api/v1/mobile/auth/otp/verify",
        json={
            "phone_number": "+639000000001",
            "challenge_id": str(uuid.uuid4()),
            "code": "secret-code-do-not-echo",
            "privacy_notice_accepted": True,
        },
    )
    assert response.status_code == 422
    assert "secret-code" not in response.text and "+639" not in response.text
    assert response.headers["cache-control"] == "no-store"


def test_mobile_does_not_accept_staff_cookie(client):
    client, auth = client
    client.cookies.set("responda_admin_session", "staff-token")
    assert client.get("/api/v1/mobile/auth/me").status_code == 401
    auth.profile.assert_awaited_once_with(None)


def test_rate_limit_applies_to_requests(client):
    client, _ = client
    for _ in range(5):
        client.post("/api/v1/mobile/auth/otp/request", json={"phone_number": "+639000000001"})
    response = client.post(
        "/api/v1/mobile/auth/otp/request", json={"phone_number": "+639000000002"}
    )
    assert response.status_code == 429 and int(response.headers["retry-after"]) > 0


def test_deployment_rejects_development_otp():
    with pytest.raises(ValidationError, match="Development OTP"):
        Settings(
            _env_file=None,
            environment="production",
            mobile_dev_otp_enabled=True,
            secret_key="x" * 40,
            debug=False,
            admin_session_cookie_secure=True,
        )
