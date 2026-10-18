import csv
import io
import json
import re
import uuid
from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta
from math import ceil
from typing import cast
from zoneinfo import ZoneInfo

from sqlalchemy import String, func, or_, select
from sqlalchemy import cast as sa_cast
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.sql import Select
from sqlalchemy.sql.elements import ColumnElement

from app.core.exceptions import ApplicationError
from app.models import (
    AuditLog,
    Incident,
    IncidentType,
    Report,
    ReportEvent,
    ReportLocation,
    ResponseAssignment,
    ResponseUnit,
)
from app.schemas.admin_assignments import AssignmentStatusValue
from app.schemas.admin_history import (
    HistoricalAssignment,
    HistoricalCounts,
    HistoricalEvent,
    HistoricalIncident,
    HistoricalIncidentDetail,
    HistoricalIncidentList,
    HistoricalReport,
    HistoricalStatus,
    HistoryPage,
)
from app.schemas.admin_reports import (
    AdminIncidentTypeListResponse,
    IncidentTypeSummary,
    PriorityValue,
    ReportSourceValue,
    VerificationStatusValue,
)

EXPORT_LIMIT = 5000
MANILA = ZoneInfo("Asia/Manila")


@dataclass(frozen=True, slots=True)
class HistoryFilters:
    search: str | None = None
    status: str | None = None
    priority: str | None = None
    incident_type_id: uuid.UUID | None = None
    date_from: date | None = None
    date_to: date | None = None
    sort: str = "newest"


def reference(prefix: str, value: uuid.UUID) -> str:
    return f"{prefix}-{str(value)[:8].upper()}"


def csv_cell(value: object) -> str:
    text = "" if value is None else str(value)
    # Quoting alone does not prevent spreadsheet formula execution.
    return "'" + text if text.lstrip().startswith(("=", "+", "-", "@", "\t", "\r")) else text


def _location() -> ColumnElement[str]:
    return func.coalesce(
        ReportLocation.landmark,
        sa_cast(ReportLocation.latitude, String) + ", " + sa_cast(ReportLocation.longitude, String),
    )


def _recorded_at() -> ColumnElement[datetime]:
    return func.coalesce(Incident.closed_at, Incident.resolved_at, Incident.updated_at)


def _conditions(filters: HistoryFilters) -> list[ColumnElement[bool]]:
    conditions: list[ColumnElement[bool]] = [
        Incident.deleted_at.is_(None),
        IncidentType.deleted_at.is_(None),
        Incident.status.in_(("resolved", "closed")),
    ]
    if filters.status:
        conditions.append(Incident.status == filters.status)
    if filters.priority:
        conditions.append(Incident.priority == filters.priority)
    if filters.incident_type_id:
        conditions.append(Incident.incident_type_id == filters.incident_type_id)
    if filters.date_from:
        start = datetime.combine(filters.date_from, time.min, MANILA).astimezone(UTC)
        conditions.append(_recorded_at() >= start)
    if filters.date_to:
        end = datetime.combine(filters.date_to + timedelta(days=1), time.min, MANILA)
        conditions.append(_recorded_at() < end.astimezone(UTC))
    if filters.search and filters.search.strip():
        text = filters.search.strip()
        if re.fullmatch(r"(?:INC|RSP)-[0-9a-fA-F-]+", text, re.IGNORECASE):
            text = text[4:]
        escaped = text.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
        pattern = f"%{escaped}%"
        report_match = (
            select(Report.report_id)
            .outerjoin(
                ReportLocation,
                (ReportLocation.report_id == Report.report_id)
                & ReportLocation.deleted_at.is_(None),
            )
            .where(
                Report.incident_id == Incident.incident_id,
                Report.deleted_at.is_(None),
                or_(
                    sa_cast(Report.report_id, String).ilike(pattern, escape="\\"),
                    ReportLocation.landmark.ilike(pattern, escape="\\"),
                ),
            )
            .exists()
        )
        team_match = (
            select(ResponseAssignment.assignment_id)
            .join(ResponseUnit, ResponseUnit.unit_id == ResponseAssignment.unit_id)
            .where(
                ResponseAssignment.incident_id == Incident.incident_id,
                ResponseAssignment.deleted_at.is_(None),
                ResponseUnit.deleted_at.is_(None),
                ResponseUnit.name.ilike(pattern, escape="\\"),
            )
            .exists()
        )
        conditions.append(
            or_(
                sa_cast(Incident.incident_id, String).ilike(pattern, escape="\\"),
                IncidentType.name.ilike(pattern, escape="\\"),
                IncidentType.code.ilike(pattern, escape="\\"),
                report_match,
                team_match,
            )
        )
    return conditions


class AdminHistoryService:
    def __init__(self, database: AsyncSession) -> None:
        self._database = database

    async def list_incident_types(self) -> AdminIncidentTypeListResponse:
        result = await self._database.execute(
            select(IncidentType)
            .join(Incident, Incident.incident_type_id == IncidentType.incident_type_id)
            .where(*_conditions(HistoryFilters()))
            .distinct()
            .order_by(IncidentType.name)
        )
        return AdminIncidentTypeListResponse(
            items=[
                IncidentTypeSummary(
                    incident_type_id=kind.incident_type_id,
                    code=kind.code,
                    name=kind.name,
                )
                for kind in result.scalars()
            ]
        )

    async def _items(
        self,
        filters: HistoryFilters,
        *,
        offset: int = 0,
        limit: int = 20,
        incident_id: uuid.UUID | None = None,
    ) -> list[HistoricalIncident]:
        report_count = (
            select(func.count(Report.report_id))
            .where(Report.incident_id == Incident.incident_id, Report.deleted_at.is_(None))
            .correlate(Incident)
            .scalar_subquery()
        )
        location = (
            select(_location())
            .select_from(Report)
            .join(ReportLocation, ReportLocation.report_id == Report.report_id)
            .where(
                Report.incident_id == Incident.incident_id,
                Report.deleted_at.is_(None),
                ReportLocation.deleted_at.is_(None),
            )
            .order_by(Report.received_at, Report.report_id)
            .limit(1)
            .correlate(Incident)
            .scalar_subquery()
        )
        assignment_conditions = (
            ResponseAssignment.incident_id == Incident.incident_id,
            ResponseAssignment.deleted_at.is_(None),
            ResponseUnit.deleted_at.is_(None),
        )
        team_count = (
            select(func.count(func.distinct(ResponseAssignment.unit_id)))
            .join(ResponseUnit, ResponseUnit.unit_id == ResponseAssignment.unit_id)
            .where(*assignment_conditions)
            .correlate(Incident)
            .scalar_subquery()
        )
        first_team = (
            select(ResponseUnit.name)
            .select_from(ResponseAssignment)
            .join(ResponseUnit, ResponseUnit.unit_id == ResponseAssignment.unit_id)
            .where(*assignment_conditions)
            .order_by(ResponseAssignment.assigned_at, ResponseAssignment.assignment_id)
            .limit(1)
            .correlate(Incident)
            .scalar_subquery()
        )
        completed = (
            select(func.count(ResponseAssignment.assignment_id))
            .join(ResponseUnit, ResponseUnit.unit_id == ResponseAssignment.unit_id)
            .where(*assignment_conditions, ResponseAssignment.status == "completed")
            .correlate(Incident)
            .scalar_subquery()
        )
        conditions = _conditions(filters)
        if incident_id:
            conditions.append(Incident.incident_id == incident_id)
        order = _recorded_at().asc() if filters.sort == "oldest" else _recorded_at().desc()
        result = await self._database.execute(
            select(
                Incident, IncidentType, location, report_count, team_count, first_team, completed
            )
            .join(IncidentType, IncidentType.incident_type_id == Incident.incident_type_id)
            .where(*conditions)
            .order_by(order, Incident.incident_id)
            .offset(offset)
            .limit(limit)
        )
        return [
            HistoricalIncident(
                incident_id=incident.incident_id,
                reference=reference("INC", incident.incident_id),
                incident_type_id=incident.incident_type_id,
                incident_type_name=kind.name,
                summary=incident.summary,
                priority=cast(PriorityValue, incident.priority),
                status=cast(HistoricalStatus, incident.status),
                location=location_text,
                report_count=reports,
                team_count=teams,
                first_team=team,
                completed_assignments=completed_count,
                opened_at=incident.opened_at,
                resolved_at=incident.resolved_at,
                closed_at=incident.closed_at,
                recorded_at=incident.closed_at or incident.resolved_at or incident.updated_at,
            )
            for incident, kind, location_text, reports, teams, team, completed_count in result.all()
        ]

    async def list_records(
        self,
        filters: HistoryFilters,
        *,
        page: int,
        page_size: int,
    ) -> HistoricalIncidentList:
        result = await self._database.execute(
            select(Incident.status, func.count(Incident.incident_id))
            .join(IncidentType, IncidentType.incident_type_id == Incident.incident_type_id)
            .where(*_conditions(filters))
            .group_by(Incident.status)
        )
        counts = HistoricalCounts(**dict(result.all()))
        total = counts.resolved + counts.closed
        return HistoricalIncidentList(
            items=await self._items(filters, offset=(page - 1) * page_size, limit=page_size),
            counts=counts,
            total=total,
            page=page,
            page_size=page_size,
            total_pages=ceil(total / page_size),
        )

    async def _page[PageItem](
        self,
        statement: Select[PageItem],
        *,
        page: int,
        page_size: int,
    ) -> tuple[list[PageItem], int]:
        count_result = await self._database.execute(
            select(func.count()).select_from(statement.order_by(None).subquery())
        )
        result = await self._database.execute(
            statement.offset((page - 1) * page_size).limit(page_size)
        )
        return list(result.scalars()), int(count_result.scalar_one())

    async def get_record(
        self,
        incident_id: uuid.UUID,
        *,
        report_page: int,
        assignment_page: int,
        event_page: int,
        page_size: int,
    ) -> HistoricalIncidentDetail:
        incidents = await self._items(HistoryFilters(), incident_id=incident_id, limit=1)
        if not incidents:
            raise ApplicationError(
                "The completed incident was not found.",
                code="historical_incident_not_found",
                status_code=404,
            )
        report_conditions = (Report.incident_id == incident_id, Report.deleted_at.is_(None))
        report_statement = select(Report).where(*report_conditions)
        reports, report_total = await self._page(
            report_statement.order_by(Report.received_at, Report.report_id),
            page=report_page,
            page_size=page_size,
        )
        locations_result = await self._database.execute(
            select(ReportLocation.report_id, _location()).where(
                ReportLocation.report_id.in_([report.report_id for report in reports]),
                ReportLocation.deleted_at.is_(None),
            )
        )
        locations = dict(locations_result.all())
        assignment_statement = (
            select(ResponseAssignment)
            .join(ResponseUnit, ResponseUnit.unit_id == ResponseAssignment.unit_id)
            .where(
                ResponseAssignment.incident_id == incident_id,
                ResponseAssignment.deleted_at.is_(None),
                ResponseUnit.deleted_at.is_(None),
            )
            .order_by(ResponseAssignment.assigned_at, ResponseAssignment.assignment_id)
        )
        assignments, assignment_total = await self._page(
            assignment_statement,
            page=assignment_page,
            page_size=page_size,
        )
        units_result = await self._database.execute(
            select(ResponseUnit).where(ResponseUnit.unit_id.in_([a.unit_id for a in assignments]))
        )
        units = {unit.unit_id: unit for unit in units_result.scalars()}
        events, event_total = await self._page(
            select(ReportEvent)
            .join(Report, Report.report_id == ReportEvent.report_id)
            .where(*report_conditions)
            .order_by(ReportEvent.created_at, ReportEvent.event_id),
            page=event_page,
            page_size=page_size,
        )
        return HistoricalIncidentDetail(
            incident=incidents[0],
            reports=HistoryPage[HistoricalReport](
                items=[
                    HistoricalReport(
                        report_id=report.report_id,
                        reference=reference("RSP", report.report_id),
                        description=report.description_original,
                        source=cast(ReportSourceValue, report.source),
                        verification_status=cast(
                            VerificationStatusValue, report.verification_status
                        ),
                        location=locations.get(report.report_id),
                        received_at=report.received_at,
                    )
                    for report in reports
                ],
                total=report_total,
                page=report_page,
                page_size=page_size,
                total_pages=ceil(report_total / page_size),
            ),
            assignments=HistoryPage[HistoricalAssignment](
                items=[
                    HistoricalAssignment(
                        assignment_id=a.assignment_id,
                        unit_name=units[a.unit_id].name,
                        unit_type=units[a.unit_id].unit_type,
                        status=cast(AssignmentStatusValue, a.status),
                        assigned_at=a.assigned_at,
                        acknowledged_at=a.acknowledged_at,
                        responding_at=a.responding_at,
                        completed_at=a.completed_at,
                        cancelled_at=a.cancelled_at,
                    )
                    for a in assignments
                ],
                total=assignment_total,
                page=assignment_page,
                page_size=page_size,
                total_pages=ceil(assignment_total / page_size),
            ),
            events=HistoryPage[HistoricalEvent](
                items=[
                    HistoricalEvent(
                        event_id=event.event_id,
                        report_reference=reference("RSP", event.report_id),
                        event_type=event.event_type,
                        created_at=event.created_at,
                    )
                    for event in events
                ],
                total=event_total,
                page=event_page,
                page_size=page_size,
                total_pages=ceil(event_total / page_size),
            ),
        )

    async def export_records(self, filters: HistoryFilters, *, staff_id: uuid.UUID) -> str:
        records = await self._items(filters, limit=EXPORT_LIMIT + 1)
        if len(records) > EXPORT_LIMIT:
            raise ApplicationError(
                "Export is limited to 5,000 incidents. Narrow the date range or filters.",
                code="history_export_too_large",
                status_code=422,
            )
        output = io.StringIO(newline="")
        writer = csv.writer(output)
        writer.writerow(
            [
                "Incident reference",
                "Incident ID",
                "Incident type",
                "Priority",
                "Status",
                "Opened at (UTC)",
                "Resolved at (UTC)",
                "Closed at (UTC)",
                "Linked reports",
                "Response teams",
                "Completed assignments",
            ]
        )
        for record in records:
            writer.writerow(
                [
                    csv_cell(value)
                    for value in (
                        record.reference,
                        record.incident_id,
                        record.incident_type_name,
                        record.priority,
                        record.status,
                        record.opened_at.astimezone(UTC).isoformat(),
                        record.resolved_at.astimezone(UTC).isoformat()
                        if record.resolved_at
                        else "",
                        record.closed_at.astimezone(UTC).isoformat() if record.closed_at else "",
                        record.report_count,
                        record.team_count,
                        record.completed_assignments,
                    )
                ]
            )
        self._database.add(
            AuditLog(
                actor_user_id=staff_id,
                action="historical_records.exported",
                entity_type="incident",
                details=json.dumps({"record_count": len(records)}),
            )
        )
        await self._database.commit()
        return "\ufeff" + output.getvalue()
