import uuid
from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

from app.api.dependencies import get_admin_assignment_service, get_admin_auth_service
from app.core.config import Environment, Settings
from app.core.exceptions import ApplicationError
from app.main import create_app
from app.models import AuthSession, User
from app.schemas.admin_assignments import (
    AdminAssignmentCreateRequest,
    AdminAssignmentListItem,
    AdminAssignmentListResponse,
    AdminAssignmentMutationResult,
    AdminAssignmentTransitionRequest,
)
from app.services.admin_auth import AuthenticatedAdmin

INCIDENT_ID = uuid.UUID("00000000-0000-0000-0000-000000000501")
UNIT_ID = uuid.UUID("00000000-0000-0000-0000-000000000502")
ASSIGNMENT_ID = uuid.UUID("00000000-0000-0000-0000-000000000503")
UPDATED_AT = datetime(2026, 10, 16, 8, 0, tzinfo=UTC)


class FakeAdminAuthService:
    def __init__(self, *, role: str = "operations_admin") -> None:
        self.user = User(
            user_id=uuid.uuid4(),
            full_name="Assignment Administrator",
            email="assignment-admin@example.com",
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
        self.token = "assignment-session"

    async def authenticate(self, token: str | None) -> AuthenticatedAdmin:
        if token != self.token:
            raise ApplicationError(
                "A valid staff session is required.",
                code="invalid_session",
                status_code=401,
            )
        return AuthenticatedAdmin(user=self.user, session=self.session)


class FakeAdminAssignmentService:
    def __init__(self) -> None:
        self.list_call: tuple[uuid.UUID, int, int] | None = None
        self.create_call: tuple[uuid.UUID, uuid.UUID, AdminAssignmentCreateRequest, str] | None = (
            None
        )
        self.transition_call: (
            tuple[uuid.UUID, uuid.UUID, AdminAssignmentTransitionRequest, str] | None
        ) = None

    async def list_assignments(
        self,
        incident_id: uuid.UUID,
        *,
        page: int,
        page_size: int,
    ) -> AdminAssignmentListResponse:
        self.list_call = (incident_id, page, page_size)
        return AdminAssignmentListResponse(
            items=[assignment_item()],
            total=1,
            page=page,
            page_size=page_size,
            total_pages=1,
        )

    async def create_assignment(
        self,
        incident_id: uuid.UUID,
        *,
        staff_id: uuid.UUID,
        payload: AdminAssignmentCreateRequest,
        ip_address: str,
    ) -> AdminAssignmentMutationResult:
        self.create_call = (incident_id, staff_id, payload, ip_address)
        return mutation_result("assigned", "assigned", "dispatched")

    async def transition_assignment(
        self,
        assignment_id: uuid.UUID,
        *,
        staff_id: uuid.UUID,
        payload: AdminAssignmentTransitionRequest,
        ip_address: str,
    ) -> AdminAssignmentMutationResult:
        self.transition_call = (assignment_id, staff_id, payload, ip_address)
        unit_status = "responding" if payload.status == "responding" else "assigned"
        return mutation_result(payload.status, unit_status, "responding")


def assignment_item(
    assignment_status: str = "assigned",
    unit_status: str = "assigned",
) -> AdminAssignmentListItem:
    return AdminAssignmentListItem.model_validate(
        {
            "assignment_id": ASSIGNMENT_ID,
            "incident_id": INCIDENT_ID,
            "unit": {
                "unit_id": UNIT_ID,
                "name": "Rescue Alpha",
                "unit_type": "Search and rescue",
                "contact": "Operations radio",
                "status": unit_status,
            },
            "assigned_by_staff_id": uuid.uuid4(),
            "status": assignment_status,
            "assigned_at": UPDATED_AT,
            "acknowledged_at": None,
            "responding_at": None,
            "completed_at": None,
            "cancelled_at": None,
            "updated_at": UPDATED_AT,
        }
    )


def mutation_result(
    assignment_status: str,
    unit_status: str,
    incident_status: str,
) -> AdminAssignmentMutationResult:
    return AdminAssignmentMutationResult.model_validate(
        {
            "assignment": assignment_item(assignment_status, unit_status),
            "incident_status": incident_status,
            "incident_updated_at": UPDATED_AT,
        }
    )


def build_test_client(
    auth_service: FakeAdminAuthService,
    assignment_service: FakeAdminAssignmentService,
) -> TestClient:
    settings = Settings(
        environment=Environment.TESTING,
        debug=False,
        allowed_origins=["http://localhost:5173"],
        _env_file=None,
    )
    application = create_app(settings)
    application.dependency_overrides[get_admin_auth_service] = lambda: auth_service
    application.dependency_overrides[get_admin_assignment_service] = lambda: assignment_service
    return TestClient(application)


def set_session(client: TestClient, auth_service: FakeAdminAuthService) -> None:
    client.cookies.set(
        "responda_admin_session",
        auth_service.token,
        path="/api/v1/admin",
    )


def test_administrator_can_list_incident_assignments() -> None:
    auth_service = FakeAdminAuthService()
    assignment_service = FakeAdminAssignmentService()

    with build_test_client(auth_service, assignment_service) as client:
        set_session(client, auth_service)
        response = client.get(
            f"/api/v1/admin/incidents/{INCIDENT_ID}/assignments?page=2&page_size=10"
        )

    assert response.status_code == 200
    assert response.json()["items"][0]["assignment_id"] == str(ASSIGNMENT_ID)
    assert response.headers["cache-control"] == "no-store, max-age=0"
    assert assignment_service.list_call == (INCIDENT_ID, 2, 10)


def test_operations_admin_can_assign_an_available_unit() -> None:
    auth_service = FakeAdminAuthService(role="operations_admin")
    assignment_service = FakeAdminAssignmentService()

    with build_test_client(auth_service, assignment_service) as client:
        set_session(client, auth_service)
        response = client.post(
            f"/api/v1/admin/incidents/{INCIDENT_ID}/assignments",
            headers={"Origin": "http://localhost:5173"},
            json={
                "unit_id": str(UNIT_ID),
                "expected_incident_updated_at": UPDATED_AT.isoformat(),
            },
        )

    assert response.status_code == 201
    assert response.json()["assignment"]["status"] == "assigned"
    assert assignment_service.create_call is not None
    assert assignment_service.create_call[0] == INCIDENT_ID
    assert assignment_service.create_call[1] == auth_service.user.user_id


def test_super_admin_can_transition_an_assignment() -> None:
    auth_service = FakeAdminAuthService(role="admin")
    assignment_service = FakeAdminAssignmentService()

    with build_test_client(auth_service, assignment_service) as client:
        set_session(client, auth_service)
        response = client.post(
            f"/api/v1/admin/assignments/{ASSIGNMENT_ID}/transitions",
            headers={"Origin": "http://localhost:5173"},
            json={
                "expected_updated_at": UPDATED_AT.isoformat(),
                "status": "responding",
            },
        )

    assert response.status_code == 200
    assert response.json()["assignment"]["status"] == "responding"
    assert assignment_service.transition_call is not None
    assert assignment_service.transition_call[0] == ASSIGNMENT_ID


def test_dispatcher_cannot_manage_assignments() -> None:
    auth_service = FakeAdminAuthService(role="dispatcher")
    assignment_service = FakeAdminAssignmentService()

    with build_test_client(auth_service, assignment_service) as client:
        set_session(client, auth_service)
        response = client.post(
            f"/api/v1/admin/incidents/{INCIDENT_ID}/assignments",
            headers={"Origin": "http://localhost:5173"},
            json={
                "unit_id": str(UNIT_ID),
                "expected_incident_updated_at": UPDATED_AT.isoformat(),
            },
        )

    assert response.status_code == 403
    assert response.json()["error"]["code"] == "assignment_management_forbidden"
    assert assignment_service.create_call is None


def test_assignment_write_rejects_untrusted_origin() -> None:
    auth_service = FakeAdminAuthService()
    assignment_service = FakeAdminAssignmentService()

    with build_test_client(auth_service, assignment_service) as client:
        set_session(client, auth_service)
        response = client.post(
            f"/api/v1/admin/incidents/{INCIDENT_ID}/assignments",
            headers={"Origin": "https://attacker.example"},
            json={
                "unit_id": str(UNIT_ID),
                "expected_incident_updated_at": UPDATED_AT.isoformat(),
            },
        )

    assert response.status_code == 403
    assert response.json()["error"]["code"] == "origin_not_allowed"
    assert assignment_service.create_call is None


def test_assignment_transition_rejects_unknown_status() -> None:
    auth_service = FakeAdminAuthService()
    assignment_service = FakeAdminAssignmentService()

    with build_test_client(auth_service, assignment_service) as client:
        set_session(client, auth_service)
        response = client.post(
            f"/api/v1/admin/assignments/{ASSIGNMENT_ID}/transitions",
            headers={"Origin": "http://localhost:5173"},
            json={
                "expected_updated_at": UPDATED_AT.isoformat(),
                "status": "teleported",
            },
        )

    assert response.status_code == 422
    assert assignment_service.transition_call is None


def test_assignment_endpoints_require_a_valid_session() -> None:
    auth_service = FakeAdminAuthService()
    assignment_service = FakeAdminAssignmentService()

    with build_test_client(auth_service, assignment_service) as client:
        response = client.get(f"/api/v1/admin/incidents/{INCIDENT_ID}/assignments")

    assert response.status_code == 401
    assert assignment_service.list_call is None
