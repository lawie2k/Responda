import uuid
from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient
from sqlalchemy.exc import OperationalError

from app.api.v1.mobile.auth import service as auth_service
from app.api.v1.sms import service as sms_service
from app.core.config import Settings
from app.core.exceptions import ApplicationError
from app.main import create_app
from app.models import SmsGateway, User
from app.schemas.sms import GatewaySmsResult, SmsDeviceCredential


class FakeAuth:
    async def authenticate(self, token):
        if token != "mobile_synthetic":
            raise ApplicationError("Sign in first.", status_code=401)
        return User(user_id=uuid.UUID(int=10)), object()


class FakeSms:
    def __init__(self):
        self.ingested = []

    async def authenticate_gateway(self, token):
        if token != "gateway_synthetic":
            raise ApplicationError("Gateway authentication failed.", status_code=401)
        return SmsGateway(gateway_id=uuid.UUID(int=20))

    async def ingest(self, gateway, payload):
        self.ingested.append(payload)
        return GatewaySmsResult(status="rejected")

    async def register_device(self, user_id, device_id):
        return SmsDeviceCredential(
            device_id=device_id,
            signing_key="synthetic_only",
            expires_at=datetime.now(UTC) + timedelta(days=180),
        )

    async def revoke_device(self, user_id, device_id):
        pass


def client():
    app = create_app(Settings(_env_file=None, environment="testing"))
    sms = FakeSms()
    app.dependency_overrides[sms_service] = lambda: sms
    app.dependency_overrides[auth_service] = lambda: FakeAuth()
    return TestClient(app), sms


def payload():
    return {
        "provider_message_id": "synthetic-1",
        "sender_number": "+639000000001",
        "body": "ordinary message",
        "received_at": datetime.now(UTC).isoformat(),
    }


def test_gateway_requires_separate_bearer_and_safe_noncacheable_responses():
    api, sms = client()
    for headers in ({}, {"Authorization": "Bearer mobile_synthetic"}):
        response = api.post("/api/v1/gateway/sms", json=payload(), headers=headers)
        assert response.status_code == 401
        assert response.headers["cache-control"] == "no-store"
        assert not sms.ingested
    response = api.post(
        "/api/v1/gateway/sms", json=payload(), headers={"Authorization": "Bearer gateway_synthetic"}
    )
    assert response.status_code == 200
    assert response.json() == {"status": "rejected", "report_id": None}
    assert response.headers["cache-control"] == "no-store"


def test_invalid_gateway_requests_never_echo_private_values():
    api, sms = client()
    value = payload() | {"body": "PRIVATE_SMS_TEXT", "sender_number": "PRIVATE_PHONE"}
    response = api.post(
        "/api/v1/gateway/sms", json=value, headers={"Authorization": "Bearer gateway_synthetic"}
    )
    assert response.status_code == 422
    assert "PRIVATE_" not in response.text
    assert response.headers["cache-control"] == "no-store"
    assert not sms.ingested
    for values in ({"received_at": "2026-10-25T10:00:00"}, {"body": "x" * 2049}, {"extra": True}):
        assert api.post("/api/v1/gateway/sms", json=payload() | values).status_code == 422


def test_mobile_device_registration_requires_bearer_and_returns_private_credential():
    api, _ = client()
    value = {"device_id": str(uuid.uuid4())}
    assert api.post("/api/v1/mobile/sms-devices", json=value).status_code == 401
    response = api.post(
        "/api/v1/mobile/sms-devices",
        json=value,
        headers={"Authorization": "Bearer mobile_synthetic"},
    )
    assert response.status_code == 201
    assert response.json()["signing_key"] == "synthetic_only"
    assert response.headers["cache-control"] == "no-store"
    response = api.delete(
        "/api/v1/mobile/sms-devices/" + value["device_id"],
        headers={"Authorization": "Bearer mobile_synthetic"},
    )
    assert response.status_code == 204


def test_registration_and_sms_delivery_have_rate_limits():
    api, _ = client()
    for _ in range(10):
        response = api.post(
            "/api/v1/gateway/sms",
            json=payload(),
            headers={"Authorization": "Bearer gateway_synthetic"},
        )
        assert response.status_code == 200
    response = api.post(
        "/api/v1/gateway/sms", json=payload(), headers={"Authorization": "Bearer gateway_synthetic"}
    )
    assert response.status_code == 429 and int(response.headers["retry-after"]) > 0
    response = api.post(
        "/api/v1/gateway/sms",
        json=payload() | {"sender_number": "+639000000002"},
        headers={"Authorization": "Bearer gateway_synthetic"},
    )
    assert response.status_code == 200
    for _ in range(10):
        api.post(
            "/api/v1/mobile/sms-devices",
            json={"device_id": str(uuid.uuid4())},
            headers={"Authorization": "Bearer mobile_synthetic"},
        )
    assert (
        api.post(
            "/api/v1/mobile/sms-devices",
            json={"device_id": str(uuid.uuid4())},
            headers={"Authorization": "Bearer mobile_synthetic"},
        ).status_code
        == 429
    )


def test_gateway_management_requires_staff_auth_and_trusted_origin():
    api, _ = client()
    value = {
        "name": "Synthetic gateway",
        "phone_number": "+639000000002",
        "device_identifier": "synthetic-phone",
    }
    assert api.post("/api/v1/admin/sms-gateways", json=value).status_code == 401
    response = api.post(
        "/api/v1/admin/sms-gateways", json=value, headers={"Origin": "https://untrusted.invalid"}
    )
    assert response.status_code == 403
    assert response.headers["cache-control"] == "no-store"


def test_storage_failure_is_retryable_and_never_echoes_sql_or_sms():
    api, sms = client()

    async def fail(*args):
        raise OperationalError("PRIVATE_SQL", {"body": "PRIVATE_SMS"}, Exception("PRIVATE_CAUSE"))

    sms.ingest = fail
    response = api.post(
        "/api/v1/gateway/sms", json=payload(), headers={"Authorization": "Bearer gateway_synthetic"}
    )
    assert response.status_code == 503
    assert "PRIVATE_" not in response.text
    assert response.headers["cache-control"] == "no-store"
