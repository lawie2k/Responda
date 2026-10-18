import csv
import io
import json
import uuid
from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import extract, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import AuditLog, Incident, IncidentType, Report, ResponseAssignment, ResponseUnit
from app.schemas.admin_analytics import (
    AdminAnalytics,
    AnalyticsCount,
    AnalyticsDay,
    AnalyticsSummary,
    AnalyticsType,
)

MANILA = ZoneInfo("Asia/Manila")


@dataclass(frozen=True, slots=True)
class AnalyticsFilters:
    date_from: date
    date_to: date
    incident_type_id: uuid.UUID | None = None


class AdminAnalyticsService:
    def __init__(self, database: AsyncSession) -> None:
        self.database = database

    async def get_analytics(self, filters: AnalyticsFilters) -> AdminAnalytics:
        start = datetime.combine(filters.date_from, time.min, MANILA).astimezone(UTC)
        end = datetime.combine(filters.date_to + timedelta(days=1), time.min, MANILA)
        report_day = func.date(func.timezone("Asia/Manila", Report.received_at))
        incident_day = func.date(func.timezone("Asia/Manila", Incident.opened_at))
        report_conditions = [
            Report.deleted_at.is_(None),
            IncidentType.deleted_at.is_(None),
            Report.received_at >= start,
            Report.received_at < end.astimezone(UTC),
        ]
        incident_conditions = [
            Incident.deleted_at.is_(None),
            IncidentType.deleted_at.is_(None),
            Incident.opened_at >= start,
            Incident.opened_at < end.astimezone(UTC),
        ]
        if filters.incident_type_id:
            report_conditions.append(Report.incident_type_id == filters.incident_type_id)
            incident_conditions.append(Incident.incident_type_id == filters.incident_type_id)

        # Group in SQL: no report narratives, locations, contacts, or individual IDs are loaded.
        report_rows = (
            await self.database.execute(
                select(
                    report_day,
                    IncidentType.incident_type_id,
                    IncidentType.name,
                    Report.verification_status,
                    Report.source,
                    func.count(),
                )
                .join(IncidentType, IncidentType.incident_type_id == Report.incident_type_id)
                .where(*report_conditions)
                .group_by(
                    report_day,
                    IncidentType.incident_type_id,
                    IncidentType.name,
                    Report.verification_status,
                    Report.source,
                )
            )
        ).all()
        incident_rows = (
            await self.database.execute(
                select(
                    incident_day,
                    IncidentType.incident_type_id,
                    IncidentType.name,
                    Incident.priority,
                    Incident.status,
                    func.count(),
                )
                .join(IncidentType, IncidentType.incident_type_id == Incident.incident_type_id)
                .where(*incident_conditions)
                .group_by(
                    incident_day,
                    IncidentType.incident_type_id,
                    IncidentType.name,
                    Incident.priority,
                    Incident.status,
                )
            )
        ).all()
        first_assignment = (
            select(
                ResponseAssignment.incident_id,
                func.min(ResponseAssignment.assigned_at).label("assigned_at"),
            )
            .join(ResponseUnit, ResponseUnit.unit_id == ResponseAssignment.unit_id)
            .join(Incident, Incident.incident_id == ResponseAssignment.incident_id)
            .where(
                ResponseAssignment.deleted_at.is_(None),
                ResponseUnit.deleted_at.is_(None),
                ResponseAssignment.status != "cancelled",
                ResponseAssignment.assigned_at >= Incident.opened_at,
            )
            .group_by(ResponseAssignment.incident_id)
            .subquery()
        )
        minutes = (
            extract("epoch", first_assignment.c.assigned_at) - extract("epoch", Incident.opened_at)
        ) / 60.0
        timing = (
            await self.database.execute(
                select(func.avg(minutes), func.count())
                .select_from(Incident)
                .join(IncidentType, IncidentType.incident_type_id == Incident.incident_type_id)
                .join(first_assignment, first_assignment.c.incident_id == Incident.incident_id)
                .where(*incident_conditions)
            )
        ).one()

        days = {
            (filters.date_from + timedelta(days=offset)).isoformat(): AnalyticsDay(
                date=filters.date_from + timedelta(days=offset)
            )
            for offset in range((filters.date_to - filters.date_from).days + 1)
        }
        kinds: dict[uuid.UUID, AnalyticsType] = {}
        sources = {
            key: AnalyticsCount(key=key, label=label, count=0)
            for key, label in (
                ("app_api", "Mobile app"),
                ("app_sms", "App SMS"),
                ("manual", "Manual intake"),
            )
        }
        priorities = {
            key: AnalyticsCount(key=key, label=key.title(), count=0)
            for key in ("critical", "high", "medium", "low")
        }
        statuses = {
            key: AnalyticsCount(key=key, label=key.title(), count=0)
            for key in ("open", "dispatched", "responding", "resolved", "closed")
        }
        for day, kind_id, name, verification, source, count in report_rows:
            bucket = days[str(day)]
            bucket.reports += count
            bucket.verified_reports += count if verification == "verified" else 0
            kinds.setdefault(kind_id, AnalyticsType(incident_type_id=kind_id, name=name))
            kinds[kind_id].reports += count
            sources[source].count += count
        for day, kind_id, name, priority, status, count in incident_rows:
            days[str(day)].incidents += count
            kinds.setdefault(kind_id, AnalyticsType(incident_type_id=kind_id, name=name))
            kinds[kind_id].incidents += count
            priorities[priority].count += count
            statuses[status].count += count
        return AdminAnalytics(
            date_from=filters.date_from,
            date_to=filters.date_to,
            generated_at=datetime.now(UTC),
            summary=AnalyticsSummary(
                reports=sum(day.reports for day in days.values()),
                verified_reports=sum(day.verified_reports for day in days.values()),
                incidents=sum(day.incidents for day in days.values()),
                critical_incidents=priorities["critical"].count,
                completed_incidents=statuses["resolved"].count + statuses["closed"].count,
                average_dispatch_minutes=round(float(timing[0]), 2)
                if timing[0] is not None
                else None,
                dispatch_samples=timing[1],
            ),
            daily=list(days.values()),
            incident_types=sorted(kinds.values(), key=lambda kind: (-kind.incidents, kind.name)),
            sources=list(sources.values()),
            priorities=list(priorities.values()),
            statuses=list(statuses.values()),
        )

    async def export_analytics(self, filters: AnalyticsFilters, *, staff_id: uuid.UUID) -> str:
        data = await self.get_analytics(filters)
        output = io.StringIO(newline="")
        writer = csv.writer(output)
        writer.writerow(
            ["Date (Asia/Manila)", "Reports received", "Verified reports", "Incidents opened"]
        )
        for day in data.daily:
            writer.writerow(
                [day.date.isoformat(), day.reports, day.verified_reports, day.incidents]
            )
        self.database.add(
            AuditLog(
                actor_user_id=staff_id,
                action="analytics.exported",
                entity_type="analytics",
                details=json.dumps({"day_count": len(data.daily)}),
            )
        )
        await self.database.commit()
        return "\ufeff" + output.getvalue()
