import uuid
from datetime import UTC, datetime

from fastapi.testclient import TestClient

from app.api.dependencies import get_mobile_report_service
from app.api.v1.mobile.auth import service as mobile_auth_service
from app.core.config import Environment, Settings
from app.core.exceptions import ApplicationError
from app.main import create_app
from app.models import User
from app.schemas.mobile_reports import MobileReportCreateResponse

CLIENT_REPORT_ID = uuid.UUID("00000000-0000-4000-8000-000000000101")
REPORT_ID = uuid.UUID("00000000-0000-4000-8000-000000000102")


class FakeMobileAuthService:
    def __init__(self) -> None:
        self.user = User(
            user_id=uuid.UUID("00000000-0000-4000-8000-000000000103"),
            full_name="",
            phone_number="+639000000001",
            role="reporter",
            is_active=True,
            phone_verified_at=datetime.now(UTC),
            privacy_notice_accepted_at=datetime.now(UTC),
        )

    async def authenticate(self, token: str | None) -> tuple[User, object]:
        if token != "mobile_verified-session":
            raise ApplicationError("Sign in with your phone number.", status_code=401)
        return self.user, object()


class FakeMobileReportService:
    def __init__(self) -> None:
        self.calls: list[tuple[User, object]] = []

    async def create_report(self, *, reporter: User, payload: object) -> MobileReportCreateResponse:
        self.calls.append((reporter, payload))
        return MobileReportCreateResponse(
            report_id=REPORT_ID,
            client_report_id=CLIENT_REPORT_ID,
            verification_status="pending",
            report_status="new",
            received_at=datetime(2026, 10, 20, 5, 0, tzinfo=UTC),
        )


def build_client() -> tuple[TestClient, FakeMobileAuthService, FakeMobileReportService]:
    app = create_app(Settings(_env_file=None, environment=Environment.TESTING))
    auth = FakeMobileAuthService()
    reports = FakeMobileReportService()
    app.dependency_overrides[mobile_auth_service] = lambda: auth
    app.dependency_overrides[get_mobile_report_service] = lambda: reports
    return TestClient(app), auth, reports


def valid_payload() -> dict[str, object]:
    return {
        "client_report_id": str(CLIENT_REPORT_ID),
        "incident_type_code": "fire",
        "description": "Smoke is coming from a house near the road.",
        "people_need_help": True,
        "additional_assistance": False,
        "immediate_danger": True,
        "latitude": 7.135421,
        "longitude": 125.9123,
        "accuracy_meters": 8.0,
        "landmark": "Kingking Highway",
        "location_captured_at": datetime.now(UTC).isoformat(),
    }


def test_report_requires_a_verified_mobile_bearer_session() -> None:
    client, _, _ = build_client()
    response = client.post("/api/v1/mobile/reports", json=valid_payload())
    assert response.status_code == 401
    assert response.headers["cache-control"] == "no-store"


def test_report_submission_returns_server_reference_and_no_store() -> None:
    client, auth, reports = build_client()
    response = client.post(
        "/api/v1/mobile/reports",
        json=valid_payload(),
        headers={"Authorization": "Bearer mobile_verified-session"},
    )
    assert response.status_code == 201
    assert response.json() == {
        "report_id": str(REPORT_ID),
        "client_report_id": str(CLIENT_REPORT_ID),
        "verification_status": "pending",
        "report_status": "new",
        "received_at": "2026-10-20T05:00:00Z",
    }
    assert response.headers["cache-control"] == "no-store"
    assert len(reports.calls) == 1
    assert reports.calls[0][0] is auth.user
    assert reports.calls[0][1].incident_type_code == "fire"


def test_invalid_report_input_does_not_echo_report_content() -> None:
    client, _, reports = build_client()
    payload = valid_payload()
    payload["description"] = "PRIVATE_REPORT_TEXT"
    payload["longitude"] = None
    response = client.post(
        "/api/v1/mobile/reports",
        json=payload,
        headers={"Authorization": "Bearer mobile_verified-session"},
    )
    assert response.status_code == 422
    assert response.headers["cache-control"] == "no-store"
    assert "PRIVATE_REPORT_TEXT" not in response.text
    assert reports.calls == []


def test_report_submission_is_rate_limited() -> None:
    client, _, _ = build_client()
    headers = {"Authorization": "Bearer mobile_verified-session"}
    for _ in range(10):
        client.post("/api/v1/mobile/reports", json=valid_payload(), headers=headers)
    response = client.post("/api/v1/mobile/reports", json=valid_payload(), headers=headers)
    assert response.status_code == 429
    assert int(response.headers["retry-after"]) > 0
