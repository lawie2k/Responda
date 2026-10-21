import json
import uuid
from datetime import UTC, datetime
from math import ceil
from typing import Literal

from sqlalchemy import Select, and_, func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ApplicationError
from app.models import (
    AuditLog,
    Incident,
    IncidentType,
    Report,
    ReportEvent,
    ReportLocation,
    ReportReview,
    ResponseAssignment,
    ResponseUnit,
    User,
)
from app.schemas.mobile_reports import (
    MobileReportCreateRequest,
    MobileReportCreateResponse,
    MobileReportListResponse,
    MobileReportTrackingResponse,
    TrackingStatus,
)


class MobileReportService:
    def __init__(self, database: AsyncSession) -> None:
        self._database = database

    @staticmethod
    def _owned_reports(
        reporter_id: uuid.UUID,
    ) -> Select[Report, IncidentType, ReportLocation, Incident]:
        return (
            select(Report, IncidentType, ReportLocation, Incident)
            .join(IncidentType, IncidentType.incident_type_id == Report.incident_type_id)
            .outerjoin(
                ReportLocation,
                and_(
                    ReportLocation.report_id == Report.report_id,
                    ReportLocation.deleted_at.is_(None),
                ),
            )
            .outerjoin(
                Incident,
                and_(
                    Incident.incident_id == Report.incident_id,
                    Incident.deleted_at.is_(None),
                ),
            )
            .where(
                Report.reporter_id == reporter_id,
                Report.deleted_at.is_(None),
                IncidentType.deleted_at.is_(None),
            )
        )

    async def list_reports(
        self,
        *,
        reporter_id: uuid.UUID,
        category: Literal["active", "completed"],
        page: int,
        page_size: int,
    ) -> MobileReportListResponse:
        owned = self._owned_reports(reporter_id)
        completed = or_(
            Report.status == "closed",
            Report.verification_status == "invalid",
            func.coalesce(Incident.status.in_(("resolved", "closed")), False),
        )
        counts = (
            await self._database.execute(
                owned.with_only_columns(
                    func.count(Report.report_id).filter(completed.is_(False)),
                    func.count(Report.report_id).filter(completed.is_(True)),
                )
            )
        ).one()
        active_count, completed_count = int(counts[0]), int(counts[1])
        total = completed_count if category == "completed" else active_count
        rows = (
            await self._database.execute(
                owned.where(completed.is_(category == "completed"))
                .order_by(Report.received_at.desc(), Report.report_id.desc())
                .offset((page - 1) * page_size)
                .limit(page_size)
            )
        ).all()
        return MobileReportListResponse(
            items=await self._tracking_items([(row[0], row[1], row[2], row[3]) for row in rows]),
            total=total,
            page=page,
            page_size=page_size,
            total_pages=ceil(total / page_size),
            active_count=active_count,
        )

    async def get_report(
        self,
        *,
        reporter_id: uuid.UUID,
        report_id: uuid.UUID,
    ) -> MobileReportTrackingResponse:
        row = (
            await self._database.execute(
                self._owned_reports(reporter_id).where(Report.report_id == report_id)
            )
        ).one_or_none()
        if row is None:
            raise ApplicationError(
                "This report is not available.",
                code="report_not_found",
                status_code=404,
            )
        return (await self._tracking_items([(row[0], row[1], row[2], row[3])]))[0]

    async def _tracking_items(
        self,
        rows: list[tuple[Report, IncidentType, ReportLocation | None, Incident | None]],
    ) -> list[MobileReportTrackingResponse]:
        if not rows:
            return []
        report_ids = [row[0].report_id for row in rows]
        reviews = (
            await self._database.execute(
                select(ReportReview.report_id, func.max(ReportReview.reviewed_at))
                .where(ReportReview.report_id.in_(report_ids), ReportReview.decision == "verified")
                .group_by(ReportReview.report_id)
            )
        ).all()
        reviewed_at = {row[0]: row[1] for row in reviews}
        incident_ids = [row[3].incident_id for row in rows if row[3] is not None]
        assignments = (
            (
                await self._database.execute(
                    select(
                        ResponseAssignment.incident_id,
                        func.min(ResponseAssignment.assigned_at),
                        func.min(ResponseAssignment.responding_at),
                    )
                    .join(ResponseUnit, ResponseUnit.unit_id == ResponseAssignment.unit_id)
                    .where(
                        ResponseAssignment.incident_id.in_(incident_ids),
                        ResponseAssignment.deleted_at.is_(None),
                        ResponseUnit.deleted_at.is_(None),
                        ResponseAssignment.status != "cancelled",
                    )
                    .group_by(ResponseAssignment.incident_id)
                )
            ).all()
            if incident_ids
            else []
        )
        assignment_times = {row[0]: (row[1], row[2]) for row in assignments}
        items = []
        for report, incident_type, location, incident in rows:
            status: TrackingStatus = "for_verification"
            times = {"received": report.received_at, "for_verification": report.received_at}
            if report.report_id in reviewed_at:
                times["validated"] = reviewed_at[report.report_id]
                times["for_dispatch"] = reviewed_at[report.report_id]
            if report.verification_status == "unverified":
                status = "needs_review"
            elif report.verification_status == "verified":
                status = "for_dispatch"
            if incident is not None:
                assigned_at, responding_at = assignment_times.get(
                    incident.incident_id, (None, None)
                )
                if assigned_at is not None:
                    times["team_assigned"] = assigned_at
                if responding_at is not None:
                    times["responding"] = responding_at
                if incident.status == "dispatched":
                    status = "team_assigned"
                elif incident.status == "responding":
                    status = "responding"
                elif incident.status == "resolved":
                    status = "resolved"
                    if incident.resolved_at is not None:
                        times["resolved"] = incident.resolved_at
            if (
                report.status == "closed"
                or report.verification_status == "invalid"
                or (incident is not None and incident.status == "closed")
            ):
                status = "closed"
                closed_at = report.closed_at or (incident.closed_at if incident else None)
                if closed_at is not None:
                    times["closed"] = closed_at
            items.append(
                MobileReportTrackingResponse(
                    report_id=report.report_id,
                    incident_type_code=incident_type.code,
                    description=report.description_original,
                    landmark=location.landmark if location else None,
                    received_at=report.received_at,
                    updated_at=max(report.updated_at, incident.updated_at)
                    if incident
                    else report.updated_at,
                    tracking_status=status,
                    milestones=times,
                )
            )
        return items

    async def create_report(
        self,
        *,
        reporter: User,
        payload: MobileReportCreateRequest,
    ) -> MobileReportCreateResponse:
        existing = await self._existing_report(payload.client_report_id)
        if existing is not None:
            if existing.deleted_at is not None or existing.reporter_id != reporter.user_id:
                raise self._duplicate_conflict()
            return self._result(existing)

        incident_type = await self._database.scalar(
            select(IncidentType).where(
                IncidentType.code == payload.incident_type_code,
                IncidentType.active.is_(True),
                IncidentType.deleted_at.is_(None),
            )
        )
        if incident_type is None:
            raise ApplicationError(
                "This incident type is not available. Update Responda and try again.",
                code="incident_type_unavailable",
                status_code=422,
            )

        now = datetime.now(UTC)
        report = Report(
            report_id=uuid.uuid4(),
            client_report_id=payload.client_report_id,
            reporter_id=reporter.user_id,
            incident_type_id=incident_type.incident_type_id,
            source="app_api",
            description_original=payload.description,
            people_need_help=payload.people_need_help,
            additional_assistance=payload.additional_assistance,
            immediate_danger=payload.immediate_danger,
            verification_status="pending",
            status="new",
            received_at=now,
            updated_at=now,
        )
        event_data = {
            "source": "app_api",
            "people_need_help": payload.people_need_help,
            "additional_assistance": payload.additional_assistance,
            "immediate_danger": payload.immediate_danger,
        }
        captured_at = payload.location_captured_at or now
        self._database.add_all(
            [
                report,
                ReportLocation(
                    location_id=uuid.uuid4(),
                    report_id=report.report_id,
                    latitude=payload.latitude,
                    longitude=payload.longitude,
                    accuracy_meters=payload.accuracy_meters,
                    landmark=payload.landmark,
                    source="gps" if payload.latitude is not None else "manual",
                    captured_at=captured_at,
                ),
                ReportEvent(
                    report_id=report.report_id,
                    actor_user_id=reporter.user_id,
                    event_type="report.created",
                    event_data=json.dumps(event_data),
                    created_at=now,
                ),
                AuditLog(
                    actor_user_id=reporter.user_id,
                    action="report.mobile.created",
                    entity_type="report",
                    entity_id=report.report_id,
                    details=json.dumps({"source": "app_api"}),
                    ip_address=None,
                    created_at=now,
                ),
            ]
        )
        try:
            await self._database.commit()
        except IntegrityError:
            await self._database.rollback()
            existing = await self._existing_report(payload.client_report_id)
            if existing is None:
                raise
            if existing.deleted_at is not None or existing.reporter_id != reporter.user_id:
                raise self._duplicate_conflict() from None
            return self._result(existing)

        return self._result(report)

    async def _existing_report(self, client_report_id: uuid.UUID) -> Report | None:
        return await self._database.scalar(
            select(Report).where(
                Report.client_report_id == client_report_id,
            )
        )

    @staticmethod
    def _result(report: Report) -> MobileReportCreateResponse:
        assert report.client_report_id is not None
        return MobileReportCreateResponse(
            report_id=report.report_id,
            client_report_id=report.client_report_id,
            verification_status="pending",
            report_status="new",
            received_at=report.received_at,
        )

    @staticmethod
    def _duplicate_conflict() -> ApplicationError:
        return ApplicationError(
            "This report could not be submitted. Start a new report and try again.",
            code="report_submission_conflict",
            status_code=409,
        )
