import uuid
from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi.testclient import TestClient

from app.api.dependencies import get_admin_auth_service, get_admin_history_service
from app.core.config import Environment, Settings
from app.core.exceptions import ApplicationError
from app.main import create_app
from app.models import AuthSession, User
from app.schemas.admin_history import (
    HistoricalCounts,
    HistoricalIncident,
    HistoricalIncidentDetail,
    HistoricalIncidentList,
    HistoryPage,
)
from app.schemas.admin_reports import AdminIncidentTypeListResponse
from app.services.admin_auth import AuthenticatedAdmin
from app.services.admin_history import AdminHistoryService

ID = uuid.uuid4()
STAMP = datetime(2026, 10, 18, tzinfo=UTC)
RECORD = HistoricalIncident(
    incident_id=ID,
    reference="INC-TEST",
    incident_type_id=uuid.uuid4(),
    incident_type_name="Test emergency",
    summary="Test summary",
    priority="high",
    status="resolved",
    location=None,
    report_count=0,
    team_count=0,
    first_team=None,
    completed_assignments=0,
    opened_at=STAMP,
    resolved_at=STAMP,
    closed_at=None,
    recorded_at=STAMP,
)


class FakeAuth:
    def __init__(self, role: str) -> None:
        self.user = User(user_id=uuid.uuid4(), full_name="Test admin", role=role, is_active=True)

    async def authenticate(self, token: str | None) -> AuthenticatedAdmin:
        if token != "test-session":
            raise ApplicationError("Sign in required.", code="invalid_session", status_code=401)
        return AuthenticatedAdmin(
            user=self.user,
            session=AuthSession(
                session_id=uuid.uuid4(),
                user_id=self.user.user_id,
                expires_at=datetime.now(UTC) + timedelta(hours=1),
                refresh_token_hash="test-hash",
            ),
        )


def client_for(role="admin", signed_in=True):
    app = create_app(Settings(environment=Environment.TESTING, _env_file=None))
    service = MagicMock(spec=AdminHistoryService)
    service.list_records = AsyncMock(
        return_value=HistoricalIncidentList(
            items=[RECORD],
            counts=HistoricalCounts(resolved=1),
            total=1,
            page=1,
            page_size=10,
            total_pages=1,
        )
    )
    empty = HistoryPage(items=[], total=0, page=1, page_size=10, total_pages=0)
    service.get_record = AsyncMock(
        return_value=HistoricalIncidentDetail(
            incident=RECORD,
            reports=empty,
            assignments=empty,
            events=empty,
        )
    )
    service.export_records = AsyncMock(return_value="Incident reference\r\nINC-TEST\r\n")
    service.list_incident_types = AsyncMock(return_value=AdminIncidentTypeListResponse(items=[]))
    app.dependency_overrides[get_admin_auth_service] = lambda: FakeAuth(role)
    app.dependency_overrides[get_admin_history_service] = lambda: service
    client = TestClient(app)
    if signed_in:
        client.cookies.set("responda_admin_session", "test-session", path="/api/v1/admin")
    return client, service


@pytest.mark.parametrize("role", ["admin", "operations_admin"])
@pytest.mark.parametrize("suffix", ["", f"/{ID}", "/export", "/incident-types"])
def test_history_reads_require_administrator_and_prevent_caching(role, suffix) -> None:
    client, _ = client_for(role)
    with client:
        response = client.get(f"/api/v1/admin/history{suffix}")
    assert response.status_code == 200
    assert response.headers["cache-control"] == "no-store, max-age=0"
    if suffix == "/export":
        assert response.headers["content-type"].startswith("text/csv")
        assert "attachment" in response.headers["content-disposition"]


@pytest.mark.parametrize("suffix", ["", f"/{ID}", "/export", "/incident-types"])
@pytest.mark.parametrize(
    "role,signed_in,expected",
    [
        ("admin", False, 401),
        ("dispatcher", True, 403),
        ("reporter", True, 403),
    ],
)
def test_history_rejects_unauthenticated_and_other_roles(suffix, role, signed_in, expected) -> None:
    client, service = client_for(role, signed_in)
    with client:
        response = client.get(f"/api/v1/admin/history{suffix}")
    assert response.status_code == expected
    service.list_records.assert_not_awaited()
    service.get_record.assert_not_awaited()
    service.export_records.assert_not_awaited()
    service.list_incident_types.assert_not_awaited()


@pytest.mark.parametrize(
    "query",
    [
        "page_size=101",
        "page=0",
        "status=open",
        "priority=urgent",
        "sort=other",
        "date_from=invalid",
        "date_from=2026-10-20&date_to=2026-10-18",
        "date_to=9999-12-31",
        "date_from=0001-01-01",
        "search=" + "x" * 101,
    ],
)
def test_history_rejects_invalid_list_filters(query) -> None:
    client, service = client_for()
    with client:
        response = client.get(f"/api/v1/admin/history?{query}")
    assert response.status_code == 422
    service.list_records.assert_not_awaited()


def test_history_preserves_server_side_filters_and_independent_detail_pages() -> None:
    client, service = client_for()
    with client:
        assert (
            client.get(
                "/api/v1/admin/history?search=RSP-test&status=closed&priority=low"
                "&date_from=2026-10-01&date_to=2026-10-18&sort=oldest&page=2&page_size=5"
            ).status_code
            == 200
        )
        assert (
            client.get(
                f"/api/v1/admin/history/{ID}?report_page=2&assignment_page=3&event_page=4"
            ).status_code
            == 200
        )
    filters = service.list_records.await_args.args[0]
    assert filters.search == "RSP-test" and filters.status == "closed" and filters.sort == "oldest"
    assert service.list_records.await_args.kwargs == {"page": 2, "page_size": 5}
    assert service.get_record.await_args.kwargs == {
        "report_page": 2,
        "assignment_page": 3,
        "event_page": 4,
        "page_size": 10,
    }


def test_history_detail_rejects_invalid_pages_and_preserves_safe_not_found_error() -> None:
    client, service = client_for()
    with client:
        assert client.get(f"/api/v1/admin/history/{ID}?event_page=0").status_code == 422
        assert client.get(f"/api/v1/admin/history/{ID}?page_size=101").status_code == 422
        service.get_record.side_effect = ApplicationError(
            "The completed incident was not found.",
            code="historical_incident_not_found",
            status_code=404,
        )
        response = client.get(f"/api/v1/admin/history/{ID}")
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "historical_incident_not_found"
