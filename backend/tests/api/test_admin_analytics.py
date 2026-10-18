import uuid
from datetime import UTC, date, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi.testclient import TestClient

from app.api.dependencies import get_admin_analytics_service, get_admin_auth_service
from app.core.config import Environment, Settings
from app.core.exceptions import ApplicationError
from app.db.session import get_database_session
from app.main import create_app
from app.models import AuthSession, User
from app.schemas.admin_analytics import AdminAnalytics, AnalyticsSummary
from app.services.admin_analytics import AdminAnalyticsService
from app.services.admin_auth import AuthenticatedAdmin


def client_for(role="admin", signed_in=True):
    app = create_app(Settings(environment=Environment.TESTING, _env_file=None))
    service = MagicMock(spec=AdminAnalyticsService)
    service.get_analytics = AsyncMock(
        return_value=AdminAnalytics(
            date_from=date(2026, 10, 1),
            date_to=date(2026, 10, 19),
            generated_at=datetime.now(UTC),
            summary=AnalyticsSummary(
                reports=0,
                verified_reports=0,
                incidents=0,
                critical_incidents=0,
                completed_incidents=0,
                average_dispatch_minutes=None,
                dispatch_samples=0,
            ),
            daily=[],
            incident_types=[],
            sources=[],
            priorities=[],
            statuses=[],
        )
    )
    service.export_analytics = AsyncMock(return_value="Date,Reports\r\n2026-10-19,0\r\n")
    database = MagicMock()
    rows = MagicMock()
    rows.all.return_value = []
    database.scalars = AsyncMock(return_value=rows)

    async def authenticate(token):
        if token != "test-session":
            raise ApplicationError("Sign in required.", code="invalid_session", status_code=401)
        user = User(user_id=uuid.uuid4(), full_name="Synthetic admin", role=role, is_active=True)
        return AuthenticatedAdmin(
            user=user,
            session=AuthSession(
                session_id=uuid.uuid4(),
                user_id=user.user_id,
                refresh_token_hash="test-hash",
                expires_at=datetime.now(UTC) + timedelta(hours=1),
            ),
        )

    auth = MagicMock()
    auth.authenticate = AsyncMock(side_effect=authenticate)
    app.dependency_overrides[get_admin_auth_service] = lambda: auth
    app.dependency_overrides[get_admin_analytics_service] = lambda: service
    app.dependency_overrides[get_database_session] = lambda: database
    client = TestClient(app)
    if signed_in:
        client.cookies.set("responda_admin_session", "test-session", path="/api/v1/admin")
    return client, service, database


@pytest.mark.parametrize("role", ["admin", "operations_admin"])
@pytest.mark.parametrize("suffix", ["", "/export", "/incident-types"])
def test_administrators_can_read_analytics_with_no_cache(role, suffix):
    client, _, _ = client_for(role)
    with client:
        response = client.get(f"/api/v1/admin/analytics{suffix}")
    assert response.status_code == 200
    assert response.headers["cache-control"] == "no-store, max-age=0"
    if suffix == "/export":
        assert response.headers["content-type"].startswith("text/csv")
        assert "attachment" in response.headers["content-disposition"]


@pytest.mark.parametrize("suffix", ["", "/export", "/incident-types"])
@pytest.mark.parametrize(
    "role,signed_in,expected",
    [
        ("admin", False, 401),
        ("dispatcher", True, 403),
        ("reporter", True, 403),
    ],
)
def test_other_roles_and_unsigned_requests_are_rejected(suffix, role, signed_in, expected):
    client, service, database = client_for(role, signed_in)
    with client:
        response = client.get(f"/api/v1/admin/analytics{suffix}")
    assert response.status_code == expected
    service.get_analytics.assert_not_awaited()
    service.export_analytics.assert_not_awaited()
    database.scalars.assert_not_awaited()


@pytest.mark.parametrize("suffix", ["", "/export"])
@pytest.mark.parametrize(
    "query",
    [
        "date_from=invalid",
        "date_from=2026-10-20&date_to=2026-10-01",
        "date_from=2025-01-01&date_to=2026-01-02",
        "incident_type_id=invalid",
        "date_to=9999-12-31",
        "date_from=0001-01-01",
    ],
)
def test_invalid_ranges_and_types_are_rejected(suffix, query):
    client, service, _ = client_for()
    with client:
        response = client.get(f"/api/v1/admin/analytics{suffix}?{query}")
    assert response.status_code == 422
    service.get_analytics.assert_not_awaited()
    service.export_analytics.assert_not_awaited()


def test_query_filters_are_forwarded_and_366_days_are_allowed():
    client, service, _ = client_for()
    kind = uuid.uuid4()
    with client:
        response = client.get(
            "/api/v1/admin/analytics?date_from=2025-01-01&date_to=2026-01-01"
            f"&incident_type_id={kind}"
        )
    assert response.status_code == 200
    filters = service.get_analytics.await_args.args[0]
    assert filters.date_from == date(2025, 1, 1)
    assert filters.date_to == date(2026, 1, 1)
    assert filters.incident_type_id == kind
