import asyncio
import uuid
from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock

from pytest import raises
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ApplicationError
from app.models import AuditLog, Incident, IncidentType, Report, ReportEvent
from app.schemas.admin_incidents import (
    AdminIncidentCreateRequest,
    AdminIncidentReportLinkRequest,
)
from app.services.admin_incidents import AdminIncidentFilters, AdminIncidentService


def scalar_result(value: object | None) -> MagicMock:
    result = MagicMock()
    result.scalar_one_or_none.return_value = value
    return result


def database_mock(*results: object | None) -> MagicMock:
    database = MagicMock(spec=AsyncSession)
    database.execute = AsyncMock(side_effect=[scalar_result(value) for value in results])
    database.flush = AsyncMock()
    database.commit = AsyncMock()
    return database


def verified_report() -> Report:
    updated_at = datetime(2026, 10, 16, 4, 0, tzinfo=UTC)
    return Report(
        report_id=uuid.uuid4(),
        client_report_id=uuid.uuid4(),
        reporter_id=uuid.uuid4(),
        incident_type_id=uuid.uuid4(),
        source="app_api",
        description_original="Test report",
        final_priority="high",
        verification_status="verified",
        status="under_review",
        received_at=updated_at,
        updated_at=updated_at,
    )


def active_incident(report: Report) -> Incident:
    opened_at = datetime(2026, 10, 16, 3, 30, tzinfo=UTC)
    return Incident(
        incident_id=uuid.uuid4(),
        incident_type_id=report.incident_type_id,
        created_by_staff_id=uuid.uuid4(),
        summary="Existing incident",
        priority="critical",
        status="open",
        opened_at=opened_at,
        updated_at=opened_at,
    )


def test_list_incidents_returns_paginated_non_deleted_records() -> None:
    report = verified_report()
    incident = active_incident(report)
    incident_type = IncidentType(
        incident_type_id=report.incident_type_id,
        code="FIRE",
        name="Fire",
        default_priority="high",
        active=True,
    )
    count_result = MagicMock()
    count_result.scalar_one.return_value = 1
    rows_result = MagicMock()
    rows_result.all.return_value = [(incident, incident_type)]
    database = MagicMock(spec=AsyncSession)
    database.execute = AsyncMock(side_effect=[count_result, rows_result])
    service = AdminIncidentService(database)

    response = asyncio.run(
        service.list_incidents(
            AdminIncidentFilters(
                page=1,
                page_size=20,
                search="fire",
                statuses=("open",),
                incident_type_id=report.incident_type_id,
            )
        )
    )

    assert response.total == 1
    assert response.total_pages == 1
    assert response.items[0].incident_id == incident.incident_id
    assert response.items[0].incident_type_name == "Fire"
    statements = [str(call.args[0]) for call in database.execute.await_args_list]
    assert all("incidents.deleted_at IS NULL" in statement for statement in statements)
    assert all("incident_types.deleted_at IS NULL" in statement for statement in statements)


def test_create_incident_links_verified_report_and_writes_history_atomically() -> None:
    report = verified_report()
    database = database_mock(report)
    service = AdminIncidentService(database)
    staff_id = uuid.uuid4()
    payload = AdminIncidentCreateRequest(
        report_id=report.report_id,
        expected_report_updated_at=report.updated_at,
        summary="  Residential fire requiring an immediate response.  ",
    )

    response = asyncio.run(
        service.create_from_report(
            staff_id=staff_id,
            payload=payload,
            ip_address="127.0.0.1",
        )
    )

    incident = database.add.call_args.args[0]
    added = database.add_all.call_args.args[0]
    event = next(item for item in added if isinstance(item, ReportEvent))
    audit = next(item for item in added if isinstance(item, AuditLog))
    assert isinstance(incident, Incident)
    assert incident.summary == "Residential fire requiring an immediate response."
    assert incident.priority == "high"
    assert incident.status == "open"
    assert report.incident_id == incident.incident_id
    assert report.status == "linked"
    assert event.event_type == "report.incident_created"
    assert audit.action == "incident.created_from_report"
    assert audit.details is not None and incident.summary not in audit.details
    assert response.operation == "created"
    assert response.incident_id == incident.incident_id
    database.flush.assert_awaited_once()
    database.commit.assert_awaited_once()


def test_link_report_to_active_matching_incident() -> None:
    report = verified_report()
    incident = active_incident(report)
    database = database_mock(report, incident)
    service = AdminIncidentService(database)
    payload = AdminIncidentReportLinkRequest(
        report_id=report.report_id,
        expected_report_updated_at=report.updated_at,
    )

    response = asyncio.run(
        service.link_report(
            incident.incident_id,
            staff_id=uuid.uuid4(),
            payload=payload,
            ip_address="127.0.0.1",
        )
    )

    added = database.add_all.call_args.args[0]
    event = next(item for item in added if isinstance(item, ReportEvent))
    audit = next(item for item in added if isinstance(item, AuditLog))
    assert report.incident_id == incident.incident_id
    assert report.status == "linked"
    assert event.event_type == "report.incident_linked"
    assert audit.action == "incident.report_linked"
    assert response.operation == "linked"
    assert response.priority == "critical"
    database.commit.assert_awaited_once()


def test_stale_report_cannot_create_an_incident() -> None:
    report = verified_report()
    database = database_mock(report)
    service = AdminIncidentService(database)
    payload = AdminIncidentCreateRequest(
        report_id=report.report_id,
        expected_report_updated_at=report.updated_at - timedelta(seconds=1),
        summary="Test incident",
    )

    with raises(ApplicationError) as error:
        asyncio.run(
            service.create_from_report(
                staff_id=uuid.uuid4(),
                payload=payload,
                ip_address="127.0.0.1",
            )
        )

    assert error.value.code == "incident_link_conflict"
    database.add.assert_not_called()
    database.commit.assert_not_awaited()


def test_unverified_report_cannot_create_an_incident() -> None:
    report = verified_report()
    report.verification_status = "unverified"
    database = database_mock(report)
    service = AdminIncidentService(database)
    payload = AdminIncidentCreateRequest(
        report_id=report.report_id,
        expected_report_updated_at=report.updated_at,
        summary="Test incident",
    )

    with raises(ApplicationError) as error:
        asyncio.run(
            service.create_from_report(
                staff_id=uuid.uuid4(),
                payload=payload,
                ip_address="127.0.0.1",
            )
        )

    assert error.value.code == "report_not_linkable"
    database.commit.assert_not_awaited()


def test_report_cannot_link_to_closed_incident() -> None:
    report = verified_report()
    incident = active_incident(report)
    incident.status = "closed"
    database = database_mock(report, incident)
    service = AdminIncidentService(database)
    payload = AdminIncidentReportLinkRequest(
        report_id=report.report_id,
        expected_report_updated_at=report.updated_at,
    )

    with raises(ApplicationError) as error:
        asyncio.run(
            service.link_report(
                incident.incident_id,
                staff_id=uuid.uuid4(),
                payload=payload,
                ip_address="127.0.0.1",
            )
        )

    assert error.value.code == "incident_not_linkable"
    database.commit.assert_not_awaited()


def test_report_and_existing_incident_types_must_match() -> None:
    report = verified_report()
    incident = active_incident(report)
    incident.incident_type_id = uuid.uuid4()
    database = database_mock(report, incident)
    service = AdminIncidentService(database)
    payload = AdminIncidentReportLinkRequest(
        report_id=report.report_id,
        expected_report_updated_at=report.updated_at,
    )

    with raises(ApplicationError) as error:
        asyncio.run(
            service.link_report(
                incident.incident_id,
                staff_id=uuid.uuid4(),
                payload=payload,
                ip_address="127.0.0.1",
            )
        )

    assert error.value.code == "incident_type_mismatch"
    database.commit.assert_not_awaited()
