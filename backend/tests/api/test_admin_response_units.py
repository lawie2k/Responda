import uuid
from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

from app.api.dependencies import get_admin_auth_service, get_admin_response_unit_service
from app.core.config import Environment, Settings
from app.core.exceptions import ApplicationError
from app.main import create_app
from app.models import AuthSession, User
from app.schemas.admin_response_units import (
    AdminResponseUnitCounts,
    AdminResponseUnitCreateRequest,
    AdminResponseUnitListItem,
    AdminResponseUnitListResponse,
    AdminResponseUnitUpdateRequest,
)
from app.services.admin_auth import AuthenticatedAdmin
from app.services.admin_response_units import AdminResponseUnitFilters

UNIT_ID = uuid.UUID("00000000-0000-0000-0000-000000000401")
UPDATED_AT = datetime(2026, 10, 16, 5, 0, tzinfo=UTC)


class FakeAdminAuthService:
    def __init__(self, *, role: str = "viewer") -> None:
        self.user = User(
            user_id=uuid.uuid4(),
            full_name="Response Viewer",
            email="response-viewer@example.com",
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
        self.token = "response-unit-session"

    async def authenticate(self, token: str | None) -> AuthenticatedAdmin:
        if token != self.token:
            raise ApplicationError(
                "A valid staff session is required.",
                code="invalid_session",
                status_code=401,
            )
        return AuthenticatedAdmin(user=self.user, session=self.session)


class FakeAdminResponseUnitService:
    def __init__(self) -> None:
        self.filters: AdminResponseUnitFilters | None = None
        self.create_call: tuple[uuid.UUID, AdminResponseUnitCreateRequest, str] | None = None
        self.update_call: (
            tuple[uuid.UUID, uuid.UUID, AdminResponseUnitUpdateRequest, str] | None
        ) = None

    async def list_units(self, filters: AdminResponseUnitFilters) -> AdminResponseUnitListResponse:
        self.filters = filters
        return AdminResponseUnitListResponse(
            items=[
                AdminResponseUnitListItem(
                    unit_id=UNIT_ID,
                    name="Rescue Alpha",
                    unit_type="Search and rescue",
                    contact="Operations radio",
                    status="available",
                    current_latitude=7.575,
                    current_longitude=125.95,
                    location_updated_at=UPDATED_AT,
                    created_at=UPDATED_AT,
                    updated_at=UPDATED_AT,
                )
            ],
            counts=AdminResponseUnitCounts(
                total=1,
                available=1,
                assigned=0,
                responding=0,
                offline=0,
            ),
            total=1,
            page=filters.page,
            page_size=filters.page_size,
            total_pages=1,
        )

    async def create_unit(
        self,
        *,
        staff_id: uuid.UUID,
        payload: AdminResponseUnitCreateRequest,
        ip_address: str,
    ) -> AdminResponseUnitListItem:
        self.create_call = (staff_id, payload, ip_address)
        return response_unit_item(
            name=payload.name,
            unit_type=payload.unit_type,
            contact=payload.contact,
        )

    async def update_unit(
        self,
        unit_id: uuid.UUID,
        *,
        staff_id: uuid.UUID,
        payload: AdminResponseUnitUpdateRequest,
        ip_address: str,
    ) -> AdminResponseUnitListItem:
        self.update_call = (unit_id, staff_id, payload, ip_address)
        return response_unit_item(
            name=payload.name or "Rescue Alpha",
            unit_type=payload.unit_type or "Search and rescue",
            contact=payload.contact or "Operations radio",
        )


def response_unit_item(
    *,
    name: str = "Rescue Alpha",
    unit_type: str = "Search and rescue",
    contact: str = "Operations radio",
) -> AdminResponseUnitListItem:
    return AdminResponseUnitListItem(
        unit_id=UNIT_ID,
        name=name,
        unit_type=unit_type,
        contact=contact,
        status="available",
        current_latitude=7.575,
        current_longitude=125.95,
        location_updated_at=UPDATED_AT,
        created_at=UPDATED_AT,
        updated_at=UPDATED_AT,
    )


def build_test_client(
    auth_service: FakeAdminAuthService,
    response_unit_service: FakeAdminResponseUnitService,
) -> TestClient:
    settings = Settings(
        environment=Environment.TESTING,
        debug=False,
        allowed_origins=["http://localhost:5173"],
        _env_file=None,
    )
    application = create_app(settings)
    application.dependency_overrides[get_admin_auth_service] = lambda: auth_service
    application.dependency_overrides[get_admin_response_unit_service] = lambda: (
        response_unit_service
    )
    return TestClient(application)


def set_session(client: TestClient, auth_service: FakeAdminAuthService) -> None:
    client.cookies.set(
        "responda_admin_session",
        auth_service.token,
        path="/api/v1/admin",
    )


def test_authenticated_staff_can_list_filtered_response_units() -> None:
    auth_service = FakeAdminAuthService()
    response_unit_service = FakeAdminResponseUnitService()

    with build_test_client(auth_service, response_unit_service) as client:
        set_session(client, auth_service)
        response = client.get(
            "/api/v1/admin/response-units",
            params=[
                ("page", "2"),
                ("page_size", "50"),
                ("search", "rescue"),
                ("unit_status", "available"),
                ("unit_status", "responding"),
            ],
        )

    assert response.status_code == 200
    assert response.json()["items"][0]["unit_id"] == str(UNIT_ID)
    assert response.json()["counts"]["available"] == 1
    assert response.headers["cache-control"] == "no-store, max-age=0"
    assert response_unit_service.filters == AdminResponseUnitFilters(
        page=2,
        page_size=50,
        search="rescue",
        statuses=("available", "responding"),
    )


def test_response_unit_list_requires_a_valid_session() -> None:
    auth_service = FakeAdminAuthService()
    response_unit_service = FakeAdminResponseUnitService()

    with build_test_client(auth_service, response_unit_service) as client:
        response = client.get("/api/v1/admin/response-units")

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "invalid_session"
    assert response_unit_service.filters is None


def test_response_unit_list_rejects_oversized_pages() -> None:
    auth_service = FakeAdminAuthService()
    response_unit_service = FakeAdminResponseUnitService()

    with build_test_client(auth_service, response_unit_service) as client:
        set_session(client, auth_service)
        response = client.get("/api/v1/admin/response-units?page_size=101")

    assert response.status_code == 422
    assert response_unit_service.filters is None


def test_admin_can_register_a_response_unit() -> None:
    auth_service = FakeAdminAuthService(role="admin")
    response_unit_service = FakeAdminResponseUnitService()

    with build_test_client(auth_service, response_unit_service) as client:
        set_session(client, auth_service)
        response = client.post(
            "/api/v1/admin/response-units",
            headers={"Origin": "http://localhost:5173"},
            json={
                "name": "  Rescue Bravo  ",
                "unit_type": "  Search and rescue  ",
                "contact": "  Operations radio 2  ",
            },
        )

    assert response.status_code == 201
    assert response.json()["name"] == "Rescue Bravo"
    assert response.headers["cache-control"] == "no-store, max-age=0"
    assert response_unit_service.create_call is not None
    assert response_unit_service.create_call[0] == auth_service.user.user_id


def test_admin_can_edit_response_unit_roster_details() -> None:
    auth_service = FakeAdminAuthService(role="admin")
    response_unit_service = FakeAdminResponseUnitService()

    with build_test_client(auth_service, response_unit_service) as client:
        set_session(client, auth_service)
        response = client.patch(
            f"/api/v1/admin/response-units/{UNIT_ID}",
            headers={"Origin": "http://localhost:5173"},
            json={
                "expected_updated_at": UPDATED_AT.isoformat(),
                "contact": "Updated dispatch radio",
            },
        )

    assert response.status_code == 200
    assert response.json()["contact"] == "Updated dispatch radio"
    assert response_unit_service.update_call is not None
    assert response_unit_service.update_call[0] == UNIT_ID
    assert response_unit_service.update_call[1] == auth_service.user.user_id


def test_non_admin_cannot_register_response_units() -> None:
    auth_service = FakeAdminAuthService(role="dispatcher")
    response_unit_service = FakeAdminResponseUnitService()

    with build_test_client(auth_service, response_unit_service) as client:
        set_session(client, auth_service)
        response = client.post(
            "/api/v1/admin/response-units",
            headers={"Origin": "http://localhost:5173"},
            json={
                "name": "Rescue Bravo",
                "unit_type": "Search and rescue",
                "contact": "Operations radio 2",
            },
        )

    assert response.status_code == 403
    assert response.json()["error"]["code"] == "response_unit_management_forbidden"
    assert response_unit_service.create_call is None


def test_response_unit_write_requires_a_valid_session() -> None:
    auth_service = FakeAdminAuthService(role="admin")
    response_unit_service = FakeAdminResponseUnitService()

    with build_test_client(auth_service, response_unit_service) as client:
        response = client.post(
            "/api/v1/admin/response-units",
            headers={"Origin": "http://localhost:5173"},
            json={
                "name": "Rescue Bravo",
                "unit_type": "Search and rescue",
                "contact": "Operations radio 2",
            },
        )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "invalid_session"
    assert response_unit_service.create_call is None


def test_response_unit_write_rejects_untrusted_origin() -> None:
    auth_service = FakeAdminAuthService(role="admin")
    response_unit_service = FakeAdminResponseUnitService()

    with build_test_client(auth_service, response_unit_service) as client:
        set_session(client, auth_service)
        response = client.post(
            "/api/v1/admin/response-units",
            headers={"Origin": "https://attacker.example"},
            json={
                "name": "Rescue Bravo",
                "unit_type": "Search and rescue",
                "contact": "Operations radio 2",
            },
        )

    assert response.status_code == 403
    assert response.json()["error"]["code"] == "origin_not_allowed"
    assert response_unit_service.create_call is None


def test_response_unit_write_rejects_blank_fields() -> None:
    auth_service = FakeAdminAuthService(role="admin")
    response_unit_service = FakeAdminResponseUnitService()

    with build_test_client(auth_service, response_unit_service) as client:
        set_session(client, auth_service)
        response = client.post(
            "/api/v1/admin/response-units",
            headers={"Origin": "http://localhost:5173"},
            json={"name": "  ", "unit_type": "Rescue", "contact": "Radio"},
        )

    assert response.status_code == 422
    assert response_unit_service.create_call is None
