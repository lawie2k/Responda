import uuid
from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

from app.api.dependencies import get_admin_auth_service, get_admin_incident_service
from app.core.config import Environment, Settings
from app.core.exceptions import ApplicationError
from app.main import create_app
from app.models import AuthSession, User
from app.schemas.admin_incidents import (
    AdminIncidentCreateRequest,
    AdminIncidentLinkResult,
    AdminIncidentListItem,
    AdminIncidentListResponse,
    AdminIncidentReportLinkRequest,
)
from app.services.admin_auth import AuthenticatedAdmin
from app.services.admin_incidents import AdminIncidentFilters

REPORT_ID = uuid.UUID("00000000-0000-0000-0000-000000000301")
INCIDENT_ID = uuid.UUID("00000000-0000-0000-0000-000000000302")
INCIDENT_TYPE_ID = uuid.UUID("00000000-0000-0000-0000-000000000303")
EXPECTED_UPDATED_AT = datetime(2026, 10, 16, 4, 0, tzinfo=UTC)


class FakeAdminAuthService:
    def __init__(self, *, role: str = "viewer") -> None:
        self.user = User(
            user_id=uuid.uuid4(),
            full_name="Incident Operator",
            email="operator@example.com",
            password_hash="not-returned",
            role=role,
            is_active=True,
        )
        self.session = AuthSession(
            session_id=uuid.uuid4(),
            user_id=self.user.user_id,
            refresh_token_hash="stored-hash-only",
            expires_at=datetime.now(UTC) + timedelta(hours=8),
        )
        self.token = "incident-operator-session"

    async def authenticate(self, token: str | None) -> AuthenticatedAdmin:
        if token != self.token:
            raise ApplicationError(
                "A valid staff session is required.",
                code="invalid_session",
                status_code=401,
            )
        return AuthenticatedAdmin(user=self.user, session=self.session)


class FakeAdminIncidentService:
    def __init__(self) -> None:
        self.filters: AdminIncidentFilters | None = None
        self.create_call: tuple[uuid.UUID, AdminIncidentCreateRequest, str] | None = None
        self.link_call: (
            tuple[uuid.UUID, uuid.UUID, AdminIncidentReportLinkRequest, str] | None
        ) = None

    async def list_incidents(
        self, filters: AdminIncidentFilters
    ) -> AdminIncidentListResponse:
        self.filters = filters
        return AdminIncidentListResponse(
            items=[
                AdminIncidentListItem(
                    incident_id=INCIDENT_ID,
                    incident_type_id=INCIDENT_TYPE_ID,
                    incident_type_name="Fire",
                    summary="Existing incident",
                    priority="high",
                    status="open",
                    opened_at=EXPECTED_UPDATED_AT,
                    updated_at=EXPECTED_UPDATED_AT,
                )
            ],
            total=1,
            page=filters.page,
            page_size=filters.page_size,
            total_pages=1,
        )

    async def create_from_report(
        self,
        *,
        staff_id: uuid.UUID,
        payload: AdminIncidentCreateRequest,
        ip_address: str,
    ) -> AdminIncidentLinkResult:
        self.create_call = (staff_id, payload, ip_address)
        return build_result(payload.report_id, operation="created", summary=payload.summary)

    async def link_report(
        self,
        incident_id: uuid.UUID,
        *,
        staff_id: uuid.UUID,
        payload: AdminIncidentReportLinkRequest,
        ip_address: str,
    ) -> AdminIncidentLinkResult:
        self.link_call = (incident_id, staff_id, payload, ip_address)
        return build_result(payload.report_id, operation="linked", summary="Existing incident")


def build_result(
    report_id: uuid.UUID,
    *,
    operation: str,
    summary: str,
) -> AdminIncidentLinkResult:
    return AdminIncidentLinkResult(
        incident_id=INCIDENT_ID,
        linked_report_id=report_id,
        incident_type_id=INCIDENT_TYPE_ID,
        priority="high",
        incident_status="open",
        summary=summary,
        report_status="linked",
        operation=operation,
        linked_at=datetime.now(UTC),
    )


def build_test_client(
    auth_service: FakeAdminAuthService,
    incident_service: FakeAdminIncidentService,
) -> TestClient:
    settings = Settings(
        environment=Environment.TESTING,
        debug=False,
        allowed_origins=["http://localhost:5173"],
        _env_file=None,
    )
    application = create_app(settings)
    application.dependency_overrides[get_admin_auth_service] = lambda: auth_service
    application.dependency_overrides[get_admin_incident_service] = lambda: incident_service
    return TestClient(application)


def create_payload() -> dict[str, str]:
    return {
        "report_id": str(REPORT_ID),
        "expected_report_updated_at": EXPECTED_UPDATED_AT.isoformat(),
        "summary": "Confirmed residential fire",
    }


def set_session(client: TestClient, auth_service: FakeAdminAuthService) -> None:
    client.cookies.set(
        "responda_admin_session",
        auth_service.token,
        path="/api/v1/admin",
    )


def test_authenticated_staff_can_list_filtered_incidents() -> None:
    auth_service = FakeAdminAuthService(role="viewer")
    incident_service = FakeAdminIncidentService()

    with build_test_client(auth_service, incident_service) as client:
        set_session(client, auth_service)
        response = client.get(
            "/api/v1/admin/incidents",
            params=[
                ("page", "2"),
                ("page_size", "50"),
                ("search", "fire"),
                ("incident_status", "open"),
                ("incident_status", "responding"),
                ("incident_type_id", str(INCIDENT_TYPE_ID)),
            ],
        )

    assert response.status_code == 200
    assert response.json()["items"][0]["incident_id"] == str(INCIDENT_ID)
    assert response.headers["cache-control"] == "no-store, max-age=0"
    assert incident_service.filters == AdminIncidentFilters(
        page=2,
        page_size=50,
        search="fire",
        statuses=("open", "responding"),
        incident_type_id=INCIDENT_TYPE_ID,
    )


def test_incident_list_rejects_oversized_pages() -> None:
    auth_service = FakeAdminAuthService(role="viewer")
    incident_service = FakeAdminIncidentService()

    with build_test_client(auth_service, incident_service) as client:
        set_session(client, auth_service)
        response = client.get("/api/v1/admin/incidents?page_size=101")

    assert response.status_code == 422
    assert incident_service.filters is None


def test_admin_can_create_incident_from_verified_report() -> None:
    auth_service = FakeAdminAuthService(role="admin")
    incident_service = FakeAdminIncidentService()

    with build_test_client(auth_service, incident_service) as client:
        set_session(client, auth_service)
        response = client.post(
            "/api/v1/admin/incidents",
            headers={"Origin": "http://localhost:5173"},
            json=create_payload(),
        )

    assert response.status_code == 201
    assert response.json()["operation"] == "created"
    assert response.headers["cache-control"] == "no-store, max-age=0"
    assert incident_service.create_call is not None
    assert incident_service.create_call[0] == auth_service.user.user_id


def test_dispatcher_can_link_report_to_existing_incident() -> None:
    auth_service = FakeAdminAuthService(role="dispatcher")
    incident_service = FakeAdminIncidentService()

    with build_test_client(auth_service, incident_service) as client:
        set_session(client, auth_service)
        response = client.post(
            f"/api/v1/admin/incidents/{INCIDENT_ID}/reports",
            headers={"Origin": "http://localhost:5173"},
            json={
                "report_id": str(REPORT_ID),
                "expected_report_updated_at": EXPECTED_UPDATED_AT.isoformat(),
            },
        )

    assert response.status_code == 200
    assert response.json()["operation"] == "linked"
    assert incident_service.link_call is not None
    assert incident_service.link_call[0] == INCIDENT_ID
    assert incident_service.link_call[1] == auth_service.user.user_id


def test_incident_operations_require_a_valid_session() -> None:
    auth_service = FakeAdminAuthService(role="admin")
    incident_service = FakeAdminIncidentService()

    with build_test_client(auth_service, incident_service) as client:
        response = client.post(
            "/api/v1/admin/incidents",
            headers={"Origin": "http://localhost:5173"},
            json=create_payload(),
        )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "invalid_session"
    assert incident_service.create_call is None


def test_verifier_cannot_manage_incidents() -> None:
    auth_service = FakeAdminAuthService(role="verifier")
    incident_service = FakeAdminIncidentService()

    with build_test_client(auth_service, incident_service) as client:
        set_session(client, auth_service)
        response = client.post(
            "/api/v1/admin/incidents",
            headers={"Origin": "http://localhost:5173"},
            json=create_payload(),
        )

    assert response.status_code == 403
    assert response.json()["error"]["code"] == "incident_operation_forbidden"
    assert incident_service.create_call is None


def test_incident_create_rejects_untrusted_browser_origin() -> None:
    auth_service = FakeAdminAuthService(role="admin")
    incident_service = FakeAdminIncidentService()

    with build_test_client(auth_service, incident_service) as client:
        set_session(client, auth_service)
        response = client.post(
            "/api/v1/admin/incidents",
            headers={"Origin": "https://attacker.example"},
            json=create_payload(),
        )

    assert response.status_code == 403
    assert response.json()["error"]["code"] == "origin_not_allowed"
    assert incident_service.create_call is None


def test_incident_create_rejects_blank_summary() -> None:
    auth_service = FakeAdminAuthService(role="admin")
    incident_service = FakeAdminIncidentService()
    payload = create_payload()
    payload["summary"] = "   "

    with build_test_client(auth_service, incident_service) as client:
        set_session(client, auth_service)
        response = client.post(
            "/api/v1/admin/incidents",
            headers={"Origin": "http://localhost:5173"},
            json=payload,
        )

    assert response.status_code == 422
    assert incident_service.create_call is None
