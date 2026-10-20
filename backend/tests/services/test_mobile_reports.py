import asyncio
import uuid
from datetime import UTC, datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.core.exceptions import ApplicationError
from app.models import IncidentType, Report, User
from app.schemas.mobile_reports import MobileReportCreateRequest
from app.services.mobile_reports import MobileReportService

CLIENT_REPORT_ID = uuid.UUID("00000000-0000-4000-8000-000000000201")
REPORTER_ID = uuid.UUID("00000000-0000-4000-8000-000000000202")
REPORT_ID = uuid.UUID("00000000-0000-4000-8000-000000000203")


def payload() -> MobileReportCreateRequest:
    return MobileReportCreateRequest(
        client_report_id=CLIENT_REPORT_ID,
        incident_type_code="fire",
        description="Smoke is coming from a house near the road.",
        latitude=7.1,
        longitude=125.9,
    )


def reporter(user_id: uuid.UUID = REPORTER_ID) -> User:
    return User(
        user_id=user_id,
        full_name="",
        phone_number="+639000000001",
        role="reporter",
        is_active=True,
    )


def existing_report(*, owner_id: uuid.UUID = REPORTER_ID, deleted: bool = False) -> Report:
    return Report(
        report_id=REPORT_ID,
        client_report_id=CLIENT_REPORT_ID,
        reporter_id=owner_id,
        incident_type_id=uuid.uuid4(),
        source="app_api",
        description_original="An existing report description.",
        received_at=datetime(2026, 10, 20, tzinfo=UTC),
        deleted_at=datetime.now(UTC) if deleted else None,
    )


def test_retry_with_same_client_id_returns_existing_report() -> None:
    database = SimpleNamespace(
        scalar=AsyncMock(return_value=existing_report()),
        commit=AsyncMock(),
    )
    result = asyncio.run(
        MobileReportService(database).create_report(reporter=reporter(), payload=payload())
    )
    assert result.report_id == REPORT_ID
    assert database.scalar.await_count == 1
    database.commit.assert_not_awaited()


@pytest.mark.parametrize("deleted", [False, True])
def test_client_id_cannot_reveal_or_reuse_another_users_report(deleted: bool) -> None:
    database = SimpleNamespace(
        scalar=AsyncMock(return_value=existing_report(owner_id=uuid.uuid4(), deleted=deleted)),
    )

    async def submit() -> None:
        with pytest.raises(ApplicationError) as error:
            await MobileReportService(database).create_report(
                reporter=reporter(), payload=payload()
            )
        assert error.value.status_code == 409
        assert "existing report" not in error.value.message

    asyncio.run(submit())


def test_create_commits_report_location_event_and_minimal_audit_together() -> None:
    incident_type = IncidentType(
        incident_type_id=uuid.uuid4(),
        code="fire",
        name="Fire",
        default_priority="high",
        active=True,
    )
    database = SimpleNamespace(
        scalar=AsyncMock(side_effect=[None, incident_type]),
        add_all=MagicMock(),
        commit=AsyncMock(),
    )
    result = asyncio.run(
        MobileReportService(database).create_report(reporter=reporter(), payload=payload())
    )
    records = database.add_all.call_args.args[0]
    assert result.client_report_id == CLIENT_REPORT_ID
    assert len(records) == 4
    assert records[0].source == "app_api"
    assert records[0].reporter_id == REPORTER_ID
    assert records[1].latitude == 7.1 and records[1].longitude == 125.9
    assert records[2].event_type == "report.created"
    assert records[3].action == "report.mobile.created"
    assert "description" not in records[3].details
    database.commit.assert_awaited_once()
