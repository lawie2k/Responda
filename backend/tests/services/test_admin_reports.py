import asyncio
import uuid
from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock

from pytest import raises
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ApplicationError
from app.models import (
    AuditLog,
    IncidentType,
    Report,
    ReportEvent,
    ReportLocation,
    ReportReview,
    User,
)
from app.schemas.admin_reports import AdminManualReportCreateRequest, AdminReportReviewRequest
from app.services.admin_reports import AdminReportService


def report_result(report: Report | None) -> MagicMock:
    result = MagicMock()
    result.scalar_one_or_none.return_value = report
    return result


def database_mock(report: Report | None) -> MagicMock:
    database = MagicMock(spec=AsyncSession)
    database.execute = AsyncMock(return_value=report_result(report))
    database.commit = AsyncMock()
    return database


def scalar_result(value: object | None) -> MagicMock:
    result = MagicMock()
    result.scalar_one_or_none.return_value = value
    return result


def pending_report() -> Report:
    updated_at = datetime(2026, 10, 16, 3, 0, tzinfo=UTC)
    return Report(
        report_id=uuid.uuid4(),
        client_report_id=uuid.uuid4(),
        reporter_id=uuid.uuid4(),
        incident_type_id=uuid.uuid4(),
        source="app_api",
        description_original="Test report",
        suggested_priority="high",
        verification_status="pending",
        status="new",
        received_at=updated_at,
        updated_at=updated_at,
    )


def test_review_updates_report_and_writes_review_event_and_audit_atomically() -> None:
    report = pending_report()
    database = database_mock(report)
    service = AdminReportService(database)
    reviewer_id = uuid.uuid4()
    payload = AdminReportReviewRequest(
        expected_updated_at=report.updated_at,
        decision="verified",
        final_priority="critical",
        location_accurate=True,
        possible_duplicate=False,
        callback_needed=True,
        notes="  Verified with the reporter and location.  ",
    )

    result = asyncio.run(
        service.review_report(
            report.report_id,
            reviewer_id=reviewer_id,
            payload=payload,
            ip_address="127.0.0.1",
        )
    )

    added = database.add_all.call_args.args[0]
    review = next(item for item in added if isinstance(item, ReportReview))
    event = next(item for item in added if isinstance(item, ReportEvent))
    audit = next(item for item in added if isinstance(item, AuditLog))
    assert report.verification_status == "verified"
    assert report.status == "under_review"
    assert report.final_priority == "critical"
    assert review.priority_conflict is True
    assert review.notes == "Verified with the reporter and location."
    assert event.event_type == "report.reviewed"
    assert audit.action == "report.review.completed"
    assert audit.details is not None and "notes" not in audit.details
    assert result.verification_status == "verified"
    database.commit.assert_awaited_once()


def test_invalid_review_closes_the_report() -> None:
    report = pending_report()
    database = database_mock(report)
    service = AdminReportService(database)
    payload = AdminReportReviewRequest(
        expected_updated_at=report.updated_at,
        decision="invalid",
        final_priority="high",
        notes="The submission is not an emergency report.",
    )

    result = asyncio.run(
        service.review_report(
            report.report_id,
            reviewer_id=uuid.uuid4(),
            payload=payload,
            ip_address="127.0.0.1",
        )
    )

    assert report.status == "closed"
    assert report.closed_at is not None
    assert report.final_priority is None
    assert result.report_status == "closed"
    assert result.final_priority is None
    database.commit.assert_awaited_once()


def test_stale_review_is_rejected_without_writes() -> None:
    report = pending_report()
    database = database_mock(report)
    service = AdminReportService(database)
    payload = AdminReportReviewRequest(
        expected_updated_at=report.updated_at - timedelta(seconds=1),
        decision="unverified",
        notes="Could not verify the report.",
    )

    with raises(ApplicationError) as error:
        asyncio.run(
            service.review_report(
                report.report_id,
                reviewer_id=uuid.uuid4(),
                payload=payload,
                ip_address="127.0.0.1",
            )
        )

    assert error.value.code == "report_review_conflict"
    database.add_all.assert_not_called()
    database.commit.assert_not_awaited()


def test_non_pending_report_cannot_be_reviewed_again() -> None:
    report = pending_report()
    report.verification_status = "verified"
    database = database_mock(report)
    service = AdminReportService(database)
    payload = AdminReportReviewRequest(
        expected_updated_at=report.updated_at,
        decision="unverified",
        notes="Attempted second review.",
    )

    with raises(ApplicationError) as error:
        asyncio.run(
            service.review_report(
                report.report_id,
                reviewer_id=uuid.uuid4(),
                payload=payload,
                ip_address="127.0.0.1",
            )
        )

    assert error.value.code == "report_not_pending"
    database.commit.assert_not_awaited()


def test_create_manual_report_writes_report_location_event_and_audit_atomically() -> None:
    incident_type = IncidentType(
        incident_type_id=uuid.uuid4(),
        code="fire",
        name="Fire",
        default_priority="critical",
        active=True,
    )
    database = MagicMock(spec=AsyncSession)
    database.execute = AsyncMock(side_effect=[scalar_result(incident_type), scalar_result(None)])
    database.flush = AsyncMock()
    database.commit = AsyncMock()
    service = AdminReportService(database)
    staff_id = uuid.uuid4()
    payload = AdminManualReportCreateRequest(
        incident_type_id=incident_type.incident_type_id,
        location="Municipal road near the public market",
        reporter_contact="0917 000 0000",
        intake_channel="phone_call",
        description="A vehicle collision is blocking both lanes.",
        people_need_help=True,
        additional_assistance=False,
        immediate_danger=True,
    )

    result = asyncio.run(
        service.create_manual_report(
            staff_id=staff_id,
            payload=payload,
            ip_address="127.0.0.1",
        )
    )

    reporter = database.add.call_args.args[0]
    added = database.add_all.call_args.args[0]
    report = next(item for item in added if isinstance(item, Report))
    location = next(item for item in added if isinstance(item, ReportLocation))
    event = next(item for item in added if isinstance(item, ReportEvent))
    audit = next(item for item in added if isinstance(item, AuditLog))
    assert isinstance(reporter, User)
    assert reporter.phone_number == "+639170000000"
    database.flush.assert_awaited_once()
    assert report.reporter_id == reporter.user_id
    assert report.manual_intake_channel == "phone_call"
    assert report.additional_assistance is False
    assert location.landmark == "Municipal road near the public market"
    assert location.latitude is None and location.longitude is None
    assert event.event_type == "report.created"
    assert event.actor_user_id == staff_id
    assert audit.action == "report.manual.created"
    assert audit.details is not None and "reporter_contact" not in audit.details
    assert result.report_id == report.report_id
    database.commit.assert_awaited_once()


def test_create_manual_report_rejects_an_inactive_incident_type() -> None:
    database = MagicMock(spec=AsyncSession)
    database.execute = AsyncMock(return_value=scalar_result(None))
    database.commit = AsyncMock()
    service = AdminReportService(database)
    payload = AdminManualReportCreateRequest(
        incident_type_id=uuid.uuid4(),
        location="Public market",
        reporter_contact="+639170000000",
        intake_channel="walk_in",
        description="A person needs emergency assistance.",
        people_need_help=True,
        additional_assistance=True,
        immediate_danger=False,
    )

    with raises(ApplicationError) as error:
        asyncio.run(
            service.create_manual_report(
                staff_id=uuid.uuid4(),
                payload=payload,
                ip_address="127.0.0.1",
            )
        )

    assert error.value.code == "incident_type_not_found"
    database.add_all.assert_not_called()
    database.commit.assert_not_awaited()
