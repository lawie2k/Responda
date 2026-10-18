import asyncio
import csv
import io
import json
import uuid
from datetime import UTC, date, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from sqlalchemy import create_engine, event, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session

from app.core.exceptions import ApplicationError
from app.db.base import Base
from app.models import (
    AuditLog,
    Incident,
    IncidentType,
    Report,
    ReportEvent,
    ReportLocation,
    ResponseAssignment,
    ResponseUnit,
    User,
)
from app.services.admin_history import AdminHistoryService, HistoryFilters

STAMP = datetime(2026, 10, 18, 15, 0, tzinfo=UTC)


@pytest.fixture
def history_database():
    engine = create_engine("sqlite://")

    @event.listens_for(engine, "connect")
    def register_uuid(connection, _):
        connection.create_function("gen_random_uuid", 0, lambda: uuid.uuid4().hex)

    Base.metadata.create_all(engine)
    with Session(engine) as session:
        staff = User(
            full_name="Test operator", role="admin", is_active=True, email="test@example.com"
        )
        kind = IncidentType(code="TEST", name="Test emergency", default_priority="high")
        unit = ResponseUnit(name="Test team", unit_type="Rescue", contact="not-for-export")
        session.add_all([staff, kind, unit])
        session.flush()
        incident = Incident(
            incident_type_id=kind.incident_type_id,
            summary="Private incident narrative",
            priority="high",
            status="resolved",
            opened_at=STAMP - timedelta(hours=1),
            resolved_at=STAMP,
            updated_at=STAMP,
        )
        session.add(incident)
        session.flush()
        report = Report(
            report_id=uuid.uuid4(),
            reporter_id=staff.user_id,
            incident_type_id=kind.incident_type_id,
            incident_id=incident.incident_id,
            source="manual",
            description_original="Private report narrative",
            verification_status="verified",
            status="linked",
            received_at=STAMP,
        )
        session.add_all(
            [
                report,
                ResponseAssignment(
                    incident_id=incident.incident_id,
                    unit_id=unit.unit_id,
                    assigned_by_staff_id=staff.user_id,
                    status="completed",
                    assigned_at=STAMP - timedelta(minutes=40),
                    acknowledged_at=STAMP - timedelta(minutes=35),
                    responding_at=STAMP - timedelta(minutes=30),
                    completed_at=STAMP,
                ),
            ]
        )
        session.flush()
        session.add_all(
            [
                ReportLocation(
                    report_id=report.report_id, landmark="Test landmark", source="manual"
                ),
                ReportEvent(
                    report_id=report.report_id,
                    event_type="response.completed",
                    event_data='{"private": "event payload"}',
                    notes="Private event notes",
                    created_at=STAMP,
                ),
            ]
        )
        session.commit()
        database = MagicMock(spec=AsyncSession)
        database.execute = AsyncMock(side_effect=session.execute)
        database.add.side_effect = session.add
        database.commit = AsyncMock(side_effect=session.commit)
        yield AdminHistoryService(database), session, incident, report, unit, kind, staff
    engine.dispose()


def test_history_search_and_manila_date_range_use_database_records(history_database) -> None:
    service, _, incident, report, _, kind, _ = history_database
    for search in (
        "Test team",
        "Test landmark",
        "Test emergency",
        f"RSP-{str(report.report_id)[:8]}",
    ):
        result = asyncio.run(
            service.list_records(
                HistoryFilters(
                    search=search,
                    status="resolved",
                    priority="high",
                    incident_type_id=kind.incident_type_id,
                    date_from=date(2026, 10, 18),
                    date_to=date(2026, 10, 18),
                ),
                page=1,
                page_size=1,
            )
        )
        assert result.total == result.counts.resolved == 1
        assert result.items[0].incident_id == incident.incident_id
        assert result.items[0].report_count == result.items[0].team_count == 1
    # 15:00 UTC is 23:00 in Manila, before the next local calendar date.
    assert (
        asyncio.run(
            service.list_records(
                HistoryFilters(date_from=date(2026, 10, 19)),
                page=1,
                page_size=10,
            )
        ).total
        == 0
    )
    assert (
        asyncio.run(
            service.list_records(
                HistoryFilters(search="%"),
                page=1,
                page_size=10,
            )
        ).total
        == 0
    )


def test_history_pagination_and_active_incident_exclusion(history_database) -> None:
    service, session, incident, _, _, _, _ = history_database
    session.add_all(
        [
            Incident(
                incident_type_id=incident.incident_type_id,
                summary="Closed record",
                priority="low",
                status="closed",
                opened_at=STAMP,
                closed_at=STAMP + timedelta(minutes=1),
                updated_at=STAMP,
            ),
            Incident(
                incident_type_id=incident.incident_type_id,
                summary="Active record",
                priority="high",
                status="responding",
                opened_at=STAMP,
                updated_at=STAMP,
            ),
        ]
    )
    session.commit()
    result = asyncio.run(service.list_records(HistoryFilters(), page=2, page_size=1))
    assert result.total == result.total_pages == 2
    assert result.counts.resolved == result.counts.closed == 1
    assert result.items[0].incident_id == incident.incident_id
    assert not asyncio.run(service.list_records(HistoryFilters(), page=3, page_size=1)).items


@pytest.mark.parametrize(
    "deleted", ["incident", "type", "report", "unit", "location", "assignment"]
)
def test_history_excludes_soft_deleted_records_and_search_matches(
    history_database, deleted
) -> None:
    service, session, incident, report, unit, kind, _ = history_database
    record = {
        "incident": incident,
        "type": kind,
        "report": report,
        "unit": unit,
        "location": session.scalar(select(ReportLocation)),
        "assignment": session.scalar(select(ResponseAssignment)),
    }[deleted]
    record.deleted_at = STAMP
    session.commit()
    result = asyncio.run(service.list_records(HistoryFilters(), page=1, page_size=10))
    if deleted in {"incident", "type"}:
        assert result.total == 0
        with pytest.raises(ApplicationError):
            asyncio.run(
                service.get_record(
                    incident.incident_id,
                    report_page=1,
                    assignment_page=1,
                    event_page=1,
                    page_size=10,
                )
            )
    elif deleted in {"unit", "assignment"}:
        assert result.items[0].team_count == 0
        assert (
            asyncio.run(
                service.list_records(
                    HistoryFilters(search="Test team"),
                    page=1,
                    page_size=10,
                )
            ).total
            == 0
        )
    else:
        assert result.items[0].location is None
        assert (
            asyncio.run(
                service.list_records(
                    HistoryFilters(search="Test landmark"),
                    page=1,
                    page_size=10,
                )
            ).total
            == 0
        )


def test_history_detail_is_paginated_and_omits_personal_fields(history_database) -> None:
    service, _, incident, _, _, _, _ = history_database
    result = asyncio.run(
        service.get_record(
            incident.incident_id,
            report_page=1,
            assignment_page=1,
            event_page=1,
            page_size=1,
        )
    )
    assert result.reports.total == result.assignments.total == result.events.total == 1
    assert result.assignments.items[0].completed_at is not None
    assert result.events.items[0].event_type == "response.completed"
    encoded = result.model_dump_json()
    for private in (
        "reporter_id",
        "phone_number",
        "email",
        "contact",
        "event_data",
        "Private event",
    ):
        assert private not in encoded
    page = asyncio.run(
        service.get_record(
            incident.incident_id,
            report_page=2,
            assignment_page=2,
            event_page=2,
            page_size=1,
        )
    )
    assert not page.reports.items and not page.assignments.items and not page.events.items


def test_active_or_missing_incident_cannot_be_opened_in_history(history_database) -> None:
    service, session, incident, _, _, _, _ = history_database
    incident.status = "open"
    session.commit()
    for identifier in (incident.incident_id, uuid.uuid4()):
        with pytest.raises(ApplicationError) as error:
            asyncio.run(
                service.get_record(
                    identifier,
                    report_page=1,
                    assignment_page=1,
                    event_page=1,
                    page_size=10,
                )
            )
        assert error.value.code == "historical_incident_not_found"


def test_history_type_filters_include_inactive_non_deleted_types(history_database) -> None:
    service, session, _, _, _, kind, _ = history_database
    kind.active = False
    session.commit()
    result = asyncio.run(service.list_incident_types())
    assert len(result.items) == 1
    assert result.items[0].incident_type_id == kind.incident_type_id
    kind.deleted_at = STAMP
    session.commit()
    assert not asyncio.run(service.list_incident_types()).items


def test_csv_is_filtered_formula_safe_and_privacy_minimized(history_database) -> None:
    service, session, _, _, _, kind, staff = history_database
    kind.name = '=HYPERLINK("test")'
    session.commit()
    result = asyncio.run(
        service.export_records(HistoryFilters(search="Test team"), staff_id=staff.user_id)
    )
    rows = list(csv.reader(io.StringIO(result.lstrip("\ufeff"))))
    assert len(rows) == 2
    assert rows[1][2].startswith("'=HYPERLINK")
    for private in ("Private incident", "Private report", "Test landmark", "Test team", "contact"):
        assert private not in result
    audit = session.scalar(select(AuditLog))
    assert audit is not None
    assert json.loads(audit.details) == {"record_count": 1}


def test_oversized_csv_is_rejected_without_partial_export_or_audit(history_database) -> None:
    service, session, _, _, _, _, staff = history_database
    with (
        patch("app.services.admin_history.EXPORT_LIMIT", 0),
        pytest.raises(ApplicationError) as error,
    ):
        asyncio.run(service.export_records(HistoryFilters(), staff_id=staff.user_id))
    assert error.value.code == "history_export_too_large"
    assert session.scalar(select(AuditLog)) is None
