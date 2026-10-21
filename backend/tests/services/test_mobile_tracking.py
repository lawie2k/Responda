import asyncio
import uuid
from datetime import datetime, timedelta
from unittest.mock import AsyncMock, MagicMock

import pytest
from sqlalchemy import create_engine, event
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session

from app.core.exceptions import ApplicationError
from app.db.base import Base
from app.models import (
    Incident,
    IncidentType,
    Report,
    ReportReview,
    ResponseAssignment,
    ResponseUnit,
)
from app.services.mobile_reports import MobileReportService

NOW = datetime(2026, 10, 21, 1)
OWNER = uuid.UUID("00000000-0000-4000-8000-000000000301")


@pytest.fixture
def tracking_database():
    engine = create_engine("sqlite://")

    @event.listens_for(engine, "connect")
    def setup(connection, _):
        connection.create_function("gen_random_uuid", 0, lambda: uuid.uuid4().hex)

    Base.metadata.create_all(engine)
    with Session(engine, expire_on_commit=False) as db:
        database = MagicMock(spec=AsyncSession)
        database.execute = AsyncMock(side_effect=db.execute)
        kind = IncidentType(code="fire", name="Fire", default_priority="high", active=True)
        db.add(kind)
        db.commit()
        yield MobileReportService(database), db, kind
    engine.dispose()


def add_report(db, kind, *, owner=OWNER, verification="pending", deleted=False, incident=None):
    report = Report(
        report_id=uuid.uuid4(),
        client_report_id=uuid.uuid4(),
        reporter_id=owner,
        incident_type_id=kind.incident_type_id,
        incident_id=incident.incident_id if incident else None,
        source="app_api",
        description_original="Synthetic tracking report.",
        verification_status=verification,
        status="closed" if verification == "invalid" else "new",
        received_at=NOW,
        updated_at=NOW,
        deleted_at=NOW if deleted else None,
        closed_at=NOW if verification == "invalid" else None,
    )
    db.add(report)
    db.commit()
    return report


def test_reads_exclude_other_owners_and_deleted_reports(tracking_database):
    service, db, kind = tracking_database
    own = add_report(db, kind)
    other = add_report(db, kind, owner=uuid.uuid4())
    removed = add_report(db, kind, deleted=True)
    closed = add_report(db, kind, verification="invalid")

    async def exercise():
        active = await service.list_reports(
            reporter_id=OWNER, category="active", page=1, page_size=20
        )
        assert [item.report_id for item in active.items] == [own.report_id]
        assert active.active_count == 1
        completed = await service.list_reports(
            reporter_id=OWNER, category="completed", page=1, page_size=20
        )
        assert [item.report_id for item in completed.items] == [closed.report_id]
        assert completed.items[0].tracking_status == "closed"
        for unavailable in (other.report_id, removed.report_id, uuid.uuid4()):
            with pytest.raises(ApplicationError) as error:
                await service.get_report(reporter_id=OWNER, report_id=unavailable)
            assert error.value.status_code == 404

    asyncio.run(exercise())


@pytest.mark.parametrize(
    "verification,incident_status,expected",
    [
        ("pending", None, "for_verification"),
        ("unverified", None, "needs_review"),
        ("verified", None, "for_dispatch"),
        ("verified", "open", "for_dispatch"),
        ("verified", "dispatched", "team_assigned"),
        ("verified", "responding", "responding"),
        ("verified", "resolved", "resolved"),
        ("verified", "closed", "closed"),
    ],
)
def test_current_state_comes_from_review_and_incident_without_private_staff_data(
    tracking_database,
    verification,
    incident_status,
    expected,
):
    service, db, kind = tracking_database
    incident = None
    later = NOW + timedelta(minutes=10)
    if incident_status:
        incident = Incident(
            incident_type_id=kind.incident_type_id,
            summary="Private operational summary",
            priority="high",
            status=incident_status,
            opened_at=NOW,
            updated_at=later,
            resolved_at=later if incident_status == "resolved" else None,
            closed_at=later if incident_status == "closed" else None,
        )
        db.add(incident)
        db.commit()
    report = add_report(db, kind, verification=verification, incident=incident)
    if verification == "verified":
        db.add(
            ReportReview(
                report_id=report.report_id,
                reviewed_by_staff_id=uuid.uuid4(),
                decision="verified",
                notes="Private review notes",
                reviewed_at=NOW + timedelta(minutes=2),
            )
        )
        db.commit()
    item = asyncio.run(service.get_report(reporter_id=OWNER, report_id=report.report_id))
    assert item.tracking_status == expected
    assert item.updated_at == (later if incident else NOW)
    assert item.milestones["received"] == NOW
    assert "responding" not in item.milestones
    if verification == "verified":
        assert item.milestones["validated"] == NOW + timedelta(minutes=2)
    encoded = item.model_dump_json()
    assert "Private" not in encoded
    assert "reviewed_by_staff_id" not in encoded


def test_milestones_ignore_cancelled_and_deleted_assignments(tracking_database):
    service, db, kind = tracking_database
    incident = Incident(
        incident_type_id=kind.incident_type_id,
        summary="Synthetic incident",
        priority="high",
        status="responding",
        opened_at=NOW,
        updated_at=NOW + timedelta(minutes=8),
    )
    db.add(incident)
    db.commit()
    report = add_report(db, kind, verification="verified", incident=incident)
    for offset, state, deleted in [
        (1, "cancelled", False),
        (2, "completed", True),
        (4, "responding", False),
    ]:
        unit = ResponseUnit(
            name=f"Synthetic team {offset}", unit_type="rescue", contact="PRIVATE_CONTACT"
        )
        db.add(unit)
        db.flush()
        db.add(
            ResponseAssignment(
                incident_id=incident.incident_id,
                unit_id=unit.unit_id,
                assigned_by_staff_id=uuid.uuid4(),
                status=state,
                assigned_at=NOW + timedelta(minutes=offset),
                responding_at=NOW + timedelta(minutes=offset + 1),
                deleted_at=NOW if deleted else None,
            )
        )
    db.commit()
    item = asyncio.run(service.get_report(reporter_id=OWNER, report_id=report.report_id))
    assert item.milestones["team_assigned"] == NOW + timedelta(minutes=4)
    assert item.milestones["responding"] == NOW + timedelta(minutes=5)
    assert "PRIVATE_CONTACT" not in item.model_dump_json()


def test_collection_paginates_stably_and_counts_all_active(tracking_database):
    service, db, kind = tracking_database
    for _ in range(3):
        add_report(db, kind)
    page1 = asyncio.run(
        service.list_reports(reporter_id=OWNER, category="active", page=1, page_size=2)
    )
    page2 = asyncio.run(
        service.list_reports(reporter_id=OWNER, category="active", page=2, page_size=2)
    )
    assert page1.total == 3 and page1.total_pages == 2 and page1.active_count == 3
    assert len(page1.items) == 2 and len(page2.items) == 1
    assert {item.report_id for item in page1.items}.isdisjoint(
        item.report_id for item in page2.items
    )
