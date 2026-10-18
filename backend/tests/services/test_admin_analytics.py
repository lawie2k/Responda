import asyncio
import csv
import io
import json
import uuid
from datetime import UTC, date, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock
from zoneinfo import ZoneInfo

import pytest
from sqlalchemy import create_engine, event, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session

from app.db.base import Base
from app.models import (
    AuditLog,
    Incident,
    IncidentType,
    Report,
    ResponseAssignment,
    ResponseUnit,
    User,
)
from app.services.admin_analytics import AdminAnalyticsService, AnalyticsFilters

STAMP = datetime(2026, 10, 18, 16, tzinfo=UTC)  # Midnight October 19 in Manila.
FILTERS = AnalyticsFilters(date_from=date(2026, 10, 19), date_to=date(2026, 10, 20))


@pytest.fixture
def analytics_database():
    engine = create_engine("sqlite://")

    @event.listens_for(engine, "connect")
    def register_functions(connection, _):
        connection.create_function("gen_random_uuid", 0, lambda: uuid.uuid4().hex)
        connection.create_function(
            "timezone",
            2,
            lambda zone, stamp: (
                datetime.fromisoformat(stamp)
                .replace(tzinfo=UTC)
                .astimezone(ZoneInfo(zone))
                .replace(tzinfo=None)
                .isoformat()
            ),
        )

    Base.metadata.create_all(engine)
    with Session(engine) as session:
        staff = User(
            full_name="Synthetic staff", role="admin", is_active=True, email="synthetic@example.com"
        )
        kind = IncidentType(code="SYNTHETIC", name="Synthetic emergency", default_priority="high")
        session.add_all([staff, kind])
        session.flush()
        incidents = [
            Incident(
                incident_type_id=kind.incident_type_id,
                summary="Private test narrative",
                priority="critical" if index == 0 else "low",
                status="resolved" if index == 0 else "open",
                opened_at=STAMP,
            )
            for index in range(2)
        ]
        session.add_all(incidents)
        session.flush()
        reports = [
            Report(
                reporter_id=staff.user_id,
                incident_type_id=kind.incident_type_id,
                incident_id=incidents[0].incident_id,
                source="manual",
                description_original="Private test report",
                verification_status="verified",
                received_at=STAMP + timedelta(minutes=index),
            )
            for index in range(2)
        ]
        reports.append(
            Report(
                reporter_id=staff.user_id,
                incident_type_id=kind.incident_type_id,
                source="app_sms",
                client_report_id=uuid.uuid4(),
                description_original="Private SMS report",
                verification_status="pending",
                received_at=STAMP + timedelta(days=1),
            )
        )
        reports.append(
            Report(
                reporter_id=staff.user_id,
                incident_type_id=kind.incident_type_id,
                source="manual",
                description_original="Outside date window",
                received_at=STAMP - timedelta(seconds=1),
            )
        )
        assignments = []
        for incident, minutes, status in [
            (incidents[0], 10, "completed"),
            (incidents[0], 30, "completed"),
            (incidents[0], 1, "cancelled"),
            (incidents[1], 20, "assigned"),
        ]:
            unit = ResponseUnit(
                name=f"Synthetic unit {minutes}", unit_type="Rescue", contact="private"
            )
            session.add(unit)
            session.flush()
            assignments.append(
                ResponseAssignment(
                    incident_id=incident.incident_id,
                    unit_id=unit.unit_id,
                    assigned_by_staff_id=staff.user_id,
                    status=status,
                    assigned_at=STAMP + timedelta(minutes=minutes),
                )
            )
        session.add_all([*reports, *assignments])
        session.commit()
        database = MagicMock(spec=AsyncSession)
        database.execute = AsyncMock(side_effect=session.execute)
        database.add.side_effect = session.add
        database.commit = AsyncMock(side_effect=session.commit)
        yield AdminAnalyticsService(database), session, incidents, reports, assignments, kind, staff
    engine.dispose()


def test_counts_do_not_duplicate_incidents_and_respect_manila_midnight(analytics_database):
    service, *_ = analytics_database
    result = asyncio.run(service.get_analytics(FILTERS))
    assert result.summary.reports == 3
    assert result.summary.verified_reports == result.summary.incidents == 2
    assert result.summary.completed_incidents == result.summary.critical_incidents == 1
    assert [(day.reports, day.incidents) for day in result.daily] == [(2, 2), (1, 0)]
    assert result.incident_types[0].reports == 3
    assert result.incident_types[0].incidents == 2
    assert [source.count for source in result.sources] == [0, 1, 2]
    assert result.summary.average_dispatch_minutes == 15
    assert result.summary.dispatch_samples == 2  # Additional teams do not add samples.
    serialized = result.model_dump_json()
    assert "Private" not in serialized and "private" not in serialized
    assert "reporter_id" not in serialized and 'summary":"' not in serialized


def test_soft_deletions_are_excluded_and_inactive_types_remain_visible(analytics_database):
    service, session, incidents, reports, assignments, kind, _ = analytics_database
    reports[0].deleted_at = STAMP
    incidents[0].deleted_at = STAMP
    kind.active = False
    assignments[-1].deleted_at = STAMP
    session.commit()
    result = asyncio.run(service.get_analytics(FILTERS))
    assert result.summary.reports == 2
    assert result.summary.incidents == 1
    assert result.summary.dispatch_samples == 0
    assert result.summary.average_dispatch_minutes is None
    assert result.incident_types[0].name == kind.name
    kind.deleted_at = STAMP
    session.commit()
    empty = asyncio.run(service.get_analytics(FILTERS))
    assert empty.summary.reports == empty.summary.incidents == 0


def test_deleted_units_and_preincident_assignments_do_not_affect_timing(analytics_database):
    service, session, _, _, assignments, _, _ = analytics_database
    unit = session.get(ResponseUnit, assignments[0].unit_id)
    unit.deleted_at = STAMP
    assignments[-1].assigned_at = STAMP - timedelta(minutes=5)
    session.commit()
    result = asyncio.run(service.get_analytics(FILTERS))
    assert result.summary.dispatch_samples == 1
    assert result.summary.average_dispatch_minutes == 30


def test_type_filter_and_empty_window_return_zero_filled_days(analytics_database):
    service, _, _, _, _, kind, _ = analytics_database
    matching = asyncio.run(
        service.get_analytics(
            AnalyticsFilters(
                date_from=FILTERS.date_from,
                date_to=FILTERS.date_to,
                incident_type_id=kind.incident_type_id,
            )
        )
    )
    assert matching.summary.incidents == 2
    empty = asyncio.run(
        service.get_analytics(
            AnalyticsFilters(
                date_from=date(2026, 10, 21),
                date_to=date(2026, 10, 23),
                incident_type_id=uuid.uuid4(),
            )
        )
    )
    assert len(empty.daily) == 3 and all(day.reports == 0 for day in empty.daily)
    assert empty.summary.reports == empty.summary.incidents == 0
    assert empty.summary.average_dispatch_minutes is None


def test_export_contains_only_daily_aggregates_and_minimal_audit(analytics_database):
    service, session, _, _, _, _, staff = analytics_database
    contents = asyncio.run(service.export_analytics(FILTERS, staff_id=staff.user_id))
    rows = list(csv.reader(io.StringIO(contents.lstrip("\ufeff"))))
    assert rows[0] == [
        "Date (Asia/Manila)",
        "Reports received",
        "Verified reports",
        "Incidents opened",
    ]
    assert rows[1:] == [["2026-10-19", "2", "2", "2"], ["2026-10-20", "1", "0", "0"]]
    assert "Private" not in contents and "Synthetic" not in contents
    audit = session.scalar(select(AuditLog).where(AuditLog.action == "analytics.exported"))
    assert audit.actor_user_id == staff.user_id
    assert json.loads(audit.details) == {"day_count": 2}
