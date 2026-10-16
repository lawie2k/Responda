import uuid
from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

from app.api.dependencies import get_admin_auth_service, get_admin_report_service
from app.core.config import Environment, Settings
from app.core.exceptions import ApplicationError
from app.main import create_app
from app.models import AuthSession, User
from app.schemas.admin_reports import (
    AdminReportDetailResponse,
    AdminReportListItem,
    AdminReportListResponse,
    AdminReportReviewRequest,
    AdminReportReviewResult,
    IncidentTypeSummary,
    ReporterSummary,
)
from app.services.admin_auth import AuthenticatedAdmin
from app.services.admin_reports import AdminReportFilters, AdminReportService

REPORT_ID = uuid.UUID("00000000-0000-0000-0000-000000000101")
INCIDENT_TYPE_ID = uuid.UUID("00000000-0000-0000-0000-000000000201")


class FakeAdminAuthService:
    def __init__(self, *, role: str = "operations_admin") -> None:
        self.user = User(
            user_id=uuid.uuid4(),
            full_name="Report Viewer",
            email="viewer@example.com",
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
        self.token = "report-reader-session"

    async def authenticate(self, token: str | None) -> AuthenticatedAdmin:
        if token != self.token:
            raise ApplicationError(
                "A valid staff session is required.",
                code="invalid_session",
                status_code=401,
            )
        return AuthenticatedAdmin(user=self.user, session=self.session)


class FakeAdminReportService:
    def __init__(self) -> None:
        self.filters: AdminReportFilters | None = None
        self.review_call: tuple[uuid.UUID, uuid.UUID, AdminReportReviewRequest, str] | None = None

    async def list_reports(self, filters: AdminReportFilters) -> AdminReportListResponse:
        self.filters = filters
        return AdminReportListResponse(
            items=[build_report_item()],
            total=1,
            page=filters.page,
            page_size=filters.page_size,
            total_pages=1,
        )

    async def get_report(self, report_id: uuid.UUID) -> AdminReportDetailResponse:
        if report_id != REPORT_ID:
            raise ApplicationError(
                "The requested report was not found.",
                code="report_not_found",
                status_code=404,
            )
        return AdminReportDetailResponse(
            **build_report_item().model_dump(),
            reporter=ReporterSummary(
                user_id=uuid.uuid4(),
                full_name="Sample Reporter",
                phone_number="+639000000000",
                email=None,
            ),
            attachments=[],
            translations=[],
            priority_assessments=[],
            reviews=[],
        )

    async def review_report(
        self,
        report_id: uuid.UUID,
        *,
        reviewer_id: uuid.UUID,
        payload: AdminReportReviewRequest,
        ip_address: str,
    ) -> AdminReportReviewResult:
        self.review_call = (report_id, reviewer_id, payload, ip_address)
        return AdminReportReviewResult(
            report_id=report_id,
            decision=payload.decision,
            verification_status=payload.decision,
            report_status="under_review",
            final_priority=payload.final_priority,
            reviewed_at=datetime.now(UTC),
        )


def build_report_item() -> AdminReportListItem:
    now = datetime(2026, 10, 16, 2, 30, tzinfo=UTC)
    return AdminReportListItem(
        report_id=REPORT_ID,
        client_report_id=uuid.uuid4(),
        incident_type=IncidentTypeSummary(
            incident_type_id=INCIDENT_TYPE_ID,
            code="FIRE",
            name="Fire",
        ),
        incident=None,
        source="app_api",
        description_original="Smoke is visible from a nearby house.",
        original_language="en",
        people_need_help=True,
        immediate_danger=True,
        suggested_priority="critical",
        final_priority=None,
        effective_priority="critical",
        verification_status="pending",
        status="new",
        location=None,
        received_at=now,
        updated_at=now,
        closed_at=None,
    )


def build_test_client(
    auth_service: FakeAdminAuthService,
    report_service: FakeAdminReportService,
) -> TestClient:
    settings = Settings(
        environment=Environment.TESTING,
        debug=False,
        allowed_origins=["http://localhost:5173"],
        _env_file=None,
    )
    application = create_app(settings)
    application.dependency_overrides[get_admin_auth_service] = lambda: auth_service
    application.dependency_overrides[get_admin_report_service] = lambda: report_service
    return TestClient(application)


def test_reports_require_a_valid_staff_session() -> None:
    auth_service = FakeAdminAuthService()
    report_service = FakeAdminReportService()

    with build_test_client(auth_service, report_service) as client:
        response = client.get("/api/v1/admin/reports")

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "invalid_session"
    assert report_service.filters is None


def test_report_list_forwards_validated_filters_and_pagination() -> None:
    auth_service = FakeAdminAuthService()
    report_service = FakeAdminReportService()

    with build_test_client(auth_service, report_service) as client:
        client.cookies.set(
            "responda_admin_session",
            auth_service.token,
            path="/api/v1/admin",
        )
        response = client.get(
            "/api/v1/admin/reports",
            params=[
                ("page", "2"),
                ("page_size", "25"),
                ("search", "fire"),
                ("verification_status", "pending"),
                ("priority", "critical"),
                ("priority", "high"),
                ("source", "app_api"),
                ("incident_status", "dispatched"),
                ("incident_type_id", str(INCIDENT_TYPE_ID)),
                ("sort", "oldest"),
            ],
        )

    assert response.status_code == 200
    assert response.json()["items"][0]["report_id"] == str(REPORT_ID)
    assert response.headers["cache-control"] == "no-store, max-age=0"
    assert report_service.filters == AdminReportFilters(
        page=2,
        page_size=25,
        search="fire",
        verification_statuses=("pending",),
        priorities=("critical", "high"),
        sources=("app_api",),
        incident_statuses=("dispatched",),
        incident_type_id=INCIDENT_TYPE_ID,
        sort="oldest",
    )


def test_report_list_rejects_oversized_pages() -> None:
    auth_service = FakeAdminAuthService()
    report_service = FakeAdminReportService()

    with build_test_client(auth_service, report_service) as client:
        client.cookies.set(
            "responda_admin_session",
            auth_service.token,
            path="/api/v1/admin",
        )
        response = client.get("/api/v1/admin/reports?page_size=101")

    assert response.status_code == 422
    assert report_service.filters is None


def test_report_detail_returns_protected_reporter_data_without_internal_storage_keys() -> None:
    auth_service = FakeAdminAuthService()
    report_service = FakeAdminReportService()

    with build_test_client(auth_service, report_service) as client:
        client.cookies.set(
            "responda_admin_session",
            auth_service.token,
            path="/api/v1/admin",
        )
        response = client.get(f"/api/v1/admin/reports/{REPORT_ID}")

    assert response.status_code == 200
    assert response.json()["reporter"]["full_name"] == "Sample Reporter"
    assert "storage_key" not in response.text
    assert "checksum_sha256" not in response.text
    assert response.headers["cache-control"] == "no-store, max-age=0"


def test_missing_report_has_a_stable_not_found_error() -> None:
    auth_service = FakeAdminAuthService()
    report_service = FakeAdminReportService()

    with build_test_client(auth_service, report_service) as client:
        client.cookies.set(
            "responda_admin_session",
            auth_service.token,
            path="/api/v1/admin",
        )
        response = client.get(f"/api/v1/admin/reports/{uuid.uuid4()}")

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "report_not_found"


def test_report_queries_exclude_soft_deleted_reports_by_default() -> None:
    conditions = AdminReportService._build_conditions(AdminReportFilters(page=1, page_size=20))

    assert "reports.deleted_at IS NULL" in str(conditions[0])


def test_operations_admin_can_review_a_pending_report() -> None:
    auth_service = FakeAdminAuthService(role="operations_admin")
    report_service = FakeAdminReportService()

    with build_test_client(auth_service, report_service) as client:
        client.cookies.set(
            "responda_admin_session",
            auth_service.token,
            path="/api/v1/admin",
        )
        response = client.post(
            f"/api/v1/admin/reports/{REPORT_ID}/reviews",
            headers={"Origin": "http://localhost:5173"},
            json={
                "expected_updated_at": "2026-10-16T02:30:00Z",
                "decision": "verified",
                "final_priority": "critical",
                "location_accurate": True,
                "possible_duplicate": False,
                "callback_needed": False,
                "notes": "Location and emergency details confirmed.",
            },
        )

    assert response.status_code == 200
    assert response.json()["verification_status"] == "verified"
    assert response.headers["cache-control"] == "no-store, max-age=0"
    assert report_service.review_call is not None
    assert report_service.review_call[1] == auth_service.user.user_id


def test_viewer_cannot_review_reports() -> None:
    auth_service = FakeAdminAuthService(role="viewer")
    report_service = FakeAdminReportService()

    with build_test_client(auth_service, report_service) as client:
        client.cookies.set(
            "responda_admin_session",
            auth_service.token,
            path="/api/v1/admin",
        )
        response = client.post(
            f"/api/v1/admin/reports/{REPORT_ID}/reviews",
            headers={"Origin": "http://localhost:5173"},
            json={
                "expected_updated_at": "2026-10-16T02:30:00Z",
                "decision": "unverified",
                "notes": "Reporter could not be reached.",
            },
        )

    assert response.status_code == 403
    assert response.json()["error"]["code"] == "report_review_forbidden"
    assert report_service.review_call is None


def test_verified_review_requires_priority_and_confirmed_location() -> None:
    auth_service = FakeAdminAuthService(role="operations_admin")
    report_service = FakeAdminReportService()

    with build_test_client(auth_service, report_service) as client:
        client.cookies.set(
            "responda_admin_session",
            auth_service.token,
            path="/api/v1/admin",
        )
        response = client.post(
            f"/api/v1/admin/reports/{REPORT_ID}/reviews",
            headers={"Origin": "http://localhost:5173"},
            json={
                "expected_updated_at": "2026-10-16T02:30:00Z",
                "decision": "verified",
                "notes": "Incomplete verification payload.",
            },
        )

    assert response.status_code == 422
    assert report_service.review_call is None


def test_report_review_rejects_an_untrusted_browser_origin() -> None:
    auth_service = FakeAdminAuthService(role="admin")
    report_service = FakeAdminReportService()

    with build_test_client(auth_service, report_service) as client:
        client.cookies.set(
            "responda_admin_session",
            auth_service.token,
            path="/api/v1/admin",
        )
        response = client.post(
            f"/api/v1/admin/reports/{REPORT_ID}/reviews",
            headers={"Origin": "https://attacker.example"},
            json={
                "expected_updated_at": "2026-10-16T02:30:00Z",
                "decision": "unverified",
                "notes": "This request must not reach the service.",
            },
        )

    assert response.status_code == 403
    assert response.json()["error"]["code"] == "origin_not_allowed"
    assert report_service.review_call is None
