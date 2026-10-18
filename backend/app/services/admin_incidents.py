import json
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from math import ceil
from typing import Literal, cast

from sqlalchemy import String, func, or_, select
from sqlalchemy import cast as sa_cast
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.sql.elements import ColumnElement

from app.core.exceptions import ApplicationError
from app.models import AuditLog, Incident, IncidentType, Report, ReportEvent
from app.schemas.admin_incidents import (
    AdminIncidentCreateRequest,
    AdminIncidentLinkResult,
    AdminIncidentListItem,
    AdminIncidentListResponse,
    AdminIncidentReportLinkRequest,
)
from app.schemas.admin_reports import IncidentStatusValue, PriorityValue, ReportStatusValue

IncidentLinkOperation = Literal["created", "linked"]


@dataclass(frozen=True, slots=True)
class AdminIncidentFilters:
    page: int
    page_size: int
    search: str | None = None
    statuses: tuple[str, ...] = ()
    incident_type_id: uuid.UUID | None = None


class AdminIncidentService:
    def __init__(self, database: AsyncSession) -> None:
        self._database = database

    async def list_incidents(
        self, filters: AdminIncidentFilters
    ) -> AdminIncidentListResponse:
        conditions: list[ColumnElement[bool]] = [
            Incident.deleted_at.is_(None),
            IncidentType.deleted_at.is_(None),
        ]
        if filters.search:
            escaped = (
                filters.search.strip()
                .replace("\\", "\\\\")
                .replace("%", "\\%")
                .replace("_", "\\_")
            )
            if escaped:
                pattern = f"%{escaped}%"
                conditions.append(
                    or_(
                        sa_cast(Incident.incident_id, String).ilike(pattern, escape="\\"),
                        Incident.summary.ilike(pattern, escape="\\"),
                        IncidentType.code.ilike(pattern, escape="\\"),
                        IncidentType.name.ilike(pattern, escape="\\"),
                    )
                )
        if filters.statuses:
            conditions.append(Incident.status.in_(filters.statuses))
        if filters.incident_type_id is not None:
            conditions.append(Incident.incident_type_id == filters.incident_type_id)

        count_result = await self._database.execute(
            select(func.count(Incident.incident_id))
            .join(IncidentType, IncidentType.incident_type_id == Incident.incident_type_id)
            .where(*conditions)
        )
        total = int(count_result.scalar_one())
        result = await self._database.execute(
            select(Incident, IncidentType)
            .join(IncidentType, IncidentType.incident_type_id == Incident.incident_type_id)
            .where(*conditions)
            .order_by(Incident.updated_at.desc(), Incident.incident_id.desc())
            .offset((filters.page - 1) * filters.page_size)
            .limit(filters.page_size)
        )
        return AdminIncidentListResponse(
            items=[
                AdminIncidentListItem(
                    incident_id=incident.incident_id,
                    incident_type_id=incident.incident_type_id,
                    incident_type_name=incident_type.name,
                    summary=incident.summary,
                    priority=cast(PriorityValue, incident.priority),
                    status=cast(IncidentStatusValue, incident.status),
                    opened_at=incident.opened_at,
                    updated_at=incident.updated_at,
                )
                for incident, incident_type in result.all()
            ],
            total=total,
            page=filters.page,
            page_size=filters.page_size,
            total_pages=ceil(total / filters.page_size) if total else 0,
        )

    async def create_from_report(
        self,
        *,
        staff_id: uuid.UUID,
        payload: AdminIncidentCreateRequest,
        ip_address: str,
    ) -> AdminIncidentLinkResult:
        report = await self._lock_linkable_report(
            payload.report_id,
            expected_updated_at=payload.expected_report_updated_at,
        )
        now = datetime.now(UTC)
        incident = Incident(
            incident_id=uuid.uuid4(),
            incident_type_id=report.incident_type_id,
            created_by_staff_id=staff_id,
            summary=payload.summary,
            priority=report.final_priority,
            status="open",
            opened_at=now,
            updated_at=now,
        )
        self._database.add(incident)
        await self._database.flush()
        self._link_report(
            report=report,
            incident=incident,
            staff_id=staff_id,
            ip_address=ip_address,
            now=now,
            operation="created",
        )
        await self._database.commit()
        return self._to_result(incident, report, operation="created", linked_at=now)

    async def link_report(
        self,
        incident_id: uuid.UUID,
        *,
        staff_id: uuid.UUID,
        payload: AdminIncidentReportLinkRequest,
        ip_address: str,
    ) -> AdminIncidentLinkResult:
        report = await self._lock_linkable_report(
            payload.report_id,
            expected_updated_at=payload.expected_report_updated_at,
        )
        result = await self._database.execute(
            select(Incident)
            .where(Incident.incident_id == incident_id, Incident.deleted_at.is_(None))
            .with_for_update()
        )
        incident = result.scalar_one_or_none()
        if incident is None:
            raise ApplicationError(
                "The requested incident was not found.",
                code="incident_not_found",
                status_code=404,
            )
        if incident.status not in {"open", "dispatched", "responding"}:
            raise ApplicationError(
                "Reports cannot be linked to a resolved or closed incident.",
                code="incident_not_linkable",
                status_code=409,
            )
        if incident.incident_type_id != report.incident_type_id:
            raise ApplicationError(
                "The report and incident must have the same incident type.",
                code="incident_type_mismatch",
                status_code=409,
            )

        now = datetime.now(UTC)
        self._link_report(
            report=report,
            incident=incident,
            staff_id=staff_id,
            ip_address=ip_address,
            now=now,
            operation="linked",
        )
        await self._database.commit()
        return self._to_result(incident, report, operation="linked", linked_at=now)

    async def _lock_linkable_report(
        self,
        report_id: uuid.UUID,
        *,
        expected_updated_at: datetime,
    ) -> Report:
        result = await self._database.execute(
            select(Report)
            .where(Report.report_id == report_id, Report.deleted_at.is_(None))
            .with_for_update()
        )
        report = result.scalar_one_or_none()
        if report is None:
            raise ApplicationError(
                "The requested report was not found.",
                code="report_not_found",
                status_code=404,
            )
        if report.updated_at != expected_updated_at:
            raise ApplicationError(
                "This report changed after it was opened. Reload it before linking it.",
                code="incident_link_conflict",
                status_code=409,
            )
        if report.incident_id is not None or report.status == "linked":
            raise ApplicationError(
                "This report is already linked to an incident.",
                code="report_already_linked",
                status_code=409,
            )
        if (
            report.verification_status != "verified"
            or report.status != "under_review"
            or report.final_priority is None
        ):
            raise ApplicationError(
                "Only a verified report awaiting incident linkage can be used.",
                code="report_not_linkable",
                status_code=409,
            )
        return report

    def _link_report(
        self,
        *,
        report: Report,
        incident: Incident,
        staff_id: uuid.UUID,
        ip_address: str,
        now: datetime,
        operation: IncidentLinkOperation,
    ) -> None:
        report.incident_id = incident.incident_id
        report.status = "linked"
        report.updated_at = now
        details = {
            "incident_id": str(incident.incident_id),
            "report_id": str(report.report_id),
            "operation": operation,
        }
        self._database.add_all(
            [
                ReportEvent(
                    report_id=report.report_id,
                    actor_user_id=staff_id,
                    event_type=(
                        "report.incident_created"
                        if operation == "created"
                        else "report.incident_linked"
                    ),
                    event_data=json.dumps(details),
                    created_at=now,
                ),
                AuditLog(
                    actor_user_id=staff_id,
                    action=(
                        "incident.created_from_report"
                        if operation == "created"
                        else "incident.report_linked"
                    ),
                    entity_type="incident",
                    entity_id=incident.incident_id,
                    details=json.dumps(details),
                    ip_address=ip_address,
                ),
            ]
        )

    @staticmethod
    def _to_result(
        incident: Incident,
        report: Report,
        *,
        operation: IncidentLinkOperation,
        linked_at: datetime,
    ) -> AdminIncidentLinkResult:
        return AdminIncidentLinkResult(
            incident_id=incident.incident_id,
            incident_updated_at=incident.updated_at,
            linked_report_id=report.report_id,
            incident_type_id=incident.incident_type_id,
            priority=cast(PriorityValue, incident.priority),
            incident_status=cast(IncidentStatusValue, incident.status),
            summary=incident.summary,
            report_status=cast(ReportStatusValue, report.status),
            operation=operation,
            linked_at=linked_at,
        )
