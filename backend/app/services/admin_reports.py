import json
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from math import ceil
from typing import Literal, cast

from sqlalchemy import String, and_, func, or_, select
from sqlalchemy import cast as sa_cast
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.sql.elements import ColumnElement

from app.core.exceptions import ApplicationError
from app.models import (
    AuditLog,
    Incident,
    IncidentType,
    PriorityAssessment,
    Report,
    ReportAttachment,
    ReportEvent,
    ReportLocation,
    ReportReview,
    ReportTranslation,
    User,
)
from app.schemas.admin_reports import (
    AdminIncidentTypeListResponse,
    AdminManualReportCreateRequest,
    AdminManualReportCreateResult,
    AdminReportDetailResponse,
    AdminReportListItem,
    AdminReportListResponse,
    AdminReportReviewRequest,
    AdminReportReviewResult,
    IncidentStatusValue,
    IncidentSummary,
    IncidentTypeSummary,
    ManualIntakeChannelValue,
    PriorityAssessmentResponse,
    PriorityValue,
    ReportAttachmentResponse,
    ReporterSummary,
    ReportLocationResponse,
    ReportReviewResponse,
    ReportSourceValue,
    ReportStatusValue,
    ReportTranslationResponse,
    VerificationStatusValue,
)


@dataclass(frozen=True, slots=True)
class AdminReportFilters:
    page: int
    page_size: int
    search: str | None = None
    statuses: tuple[str, ...] = ()
    verification_statuses: tuple[str, ...] = ()
    priorities: tuple[str, ...] = ()
    sources: tuple[str, ...] = ()
    incident_statuses: tuple[str, ...] = ()
    incident_type_id: uuid.UUID | None = None
    sort: str = "newest"


class AdminReportService:
    def __init__(self, database: AsyncSession) -> None:
        self._database = database

    async def list_active_incident_types(self) -> AdminIncidentTypeListResponse:
        result = await self._database.execute(
            select(IncidentType)
            .where(
                IncidentType.active.is_(True),
                IncidentType.deleted_at.is_(None),
            )
            .order_by(IncidentType.name.asc(), IncidentType.incident_type_id.asc())
        )
        return AdminIncidentTypeListResponse(
            items=[
                IncidentTypeSummary(
                    incident_type_id=incident_type.incident_type_id,
                    code=incident_type.code,
                    name=incident_type.name,
                )
                for incident_type in result.scalars()
            ]
        )

    async def create_manual_report(
        self,
        *,
        staff_id: uuid.UUID,
        payload: AdminManualReportCreateRequest,
        ip_address: str,
    ) -> AdminManualReportCreateResult:
        incident_type_result = await self._database.execute(
            select(IncidentType).where(
                IncidentType.incident_type_id == payload.incident_type_id,
                IncidentType.active.is_(True),
                IncidentType.deleted_at.is_(None),
            )
        )
        incident_type = incident_type_result.scalar_one_or_none()
        if incident_type is None:
            raise ApplicationError(
                "Select an active incident type.",
                code="incident_type_not_found",
                status_code=404,
            )

        reporter_result = await self._database.execute(
            select(User).where(User.phone_number == payload.reporter_contact)
        )
        reporter = reporter_result.scalar_one_or_none()
        now = datetime.now(UTC)
        if reporter is None:
            reporter = User(
                user_id=uuid.uuid4(),
                full_name="Unidentified reporter",
                phone_number=payload.reporter_contact,
                role="reporter",
                is_active=True,
                created_at=now,
                updated_at=now,
            )
            self._database.add(reporter)
            await self._database.flush()

        report = Report(
            report_id=uuid.uuid4(),
            reporter_id=reporter.user_id,
            incident_type_id=incident_type.incident_type_id,
            source="manual",
            manual_intake_channel=payload.intake_channel,
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
            "source": "manual",
            "intake_channel": payload.intake_channel,
            "people_need_help": payload.people_need_help,
            "additional_assistance": payload.additional_assistance,
            "immediate_danger": payload.immediate_danger,
        }
        self._database.add_all(
            [
                report,
                ReportLocation(
                    location_id=uuid.uuid4(),
                    report_id=report.report_id,
                    landmark=payload.location,
                    source="manual",
                    captured_at=now,
                ),
                ReportEvent(
                    report_id=report.report_id,
                    actor_user_id=staff_id,
                    event_type="report.created",
                    event_data=json.dumps(event_data),
                    created_at=now,
                ),
                AuditLog(
                    actor_user_id=staff_id,
                    action="report.manual.created",
                    entity_type="report",
                    entity_id=report.report_id,
                    details=json.dumps(
                        {
                            "source": "manual",
                            "intake_channel": payload.intake_channel,
                            "incident_type_id": str(incident_type.incident_type_id),
                        }
                    ),
                    ip_address=ip_address,
                    created_at=now,
                ),
            ]
        )
        await self._database.commit()
        return AdminManualReportCreateResult(
            report_id=report.report_id,
            verification_status="pending",
            report_status="new",
            received_at=now,
        )

    async def list_reports(self, filters: AdminReportFilters) -> AdminReportListResponse:
        conditions = self._build_conditions(filters)
        count_statement = (
            select(func.count(Report.report_id))
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
                and_(Incident.incident_id == Report.incident_id, Incident.deleted_at.is_(None)),
            )
        )
        if conditions:
            count_statement = count_statement.where(*conditions)

        total_result = await self._database.execute(count_statement)
        total = int(total_result.scalar_one())

        ordering = Report.received_at.desc()
        if filters.sort == "oldest":
            ordering = Report.received_at.asc()

        statement = (
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
                and_(Incident.incident_id == Report.incident_id, Incident.deleted_at.is_(None)),
            )
            .order_by(ordering, Report.report_id.desc())
            .offset((filters.page - 1) * filters.page_size)
            .limit(filters.page_size)
        )
        if conditions:
            statement = statement.where(*conditions)

        result = await self._database.execute(statement)
        items = [
            self._to_list_item(report, incident_type, location, incident)
            for report, incident_type, location, incident in result.all()
        ]
        return AdminReportListResponse(
            items=items,
            total=total,
            page=filters.page,
            page_size=filters.page_size,
            total_pages=ceil(total / filters.page_size) if total else 0,
        )

    async def get_report(self, report_id: uuid.UUID) -> AdminReportDetailResponse:
        statement = (
            select(Report, IncidentType, ReportLocation, Incident, User)
            .join(IncidentType, IncidentType.incident_type_id == Report.incident_type_id)
            .join(User, User.user_id == Report.reporter_id)
            .outerjoin(
                ReportLocation,
                and_(
                    ReportLocation.report_id == Report.report_id,
                    ReportLocation.deleted_at.is_(None),
                ),
            )
            .outerjoin(
                Incident,
                and_(Incident.incident_id == Report.incident_id, Incident.deleted_at.is_(None)),
            )
            .where(Report.report_id == report_id, Report.deleted_at.is_(None))
        )
        result = await self._database.execute(statement)
        row = result.one_or_none()
        if row is None:
            raise ApplicationError(
                "The requested report was not found.",
                code="report_not_found",
                status_code=404,
            )

        report, incident_type, location, incident, reporter = row
        attachments = await self._list_attachments(report_id)
        translations = await self._list_translations(report_id)
        assessments = await self._list_priority_assessments(report_id)
        reviews = await self._list_reviews(report_id)
        return AdminReportDetailResponse(
            **self._to_list_item(report, incident_type, location, incident).model_dump(),
            reporter=ReporterSummary(
                user_id=reporter.user_id,
                full_name=reporter.full_name,
                phone_number=reporter.phone_number,
                email=reporter.email,
            ),
            attachments=attachments,
            translations=translations,
            priority_assessments=assessments,
            reviews=reviews,
        )

    async def review_report(
        self,
        report_id: uuid.UUID,
        *,
        reviewer_id: uuid.UUID,
        payload: AdminReportReviewRequest,
        ip_address: str,
    ) -> AdminReportReviewResult:
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
        if report.updated_at != payload.expected_updated_at:
            raise ApplicationError(
                "This report changed after it was opened. Reload it before reviewing.",
                code="report_review_conflict",
                status_code=409,
            )
        if report.verification_status != "pending" or report.status == "closed":
            raise ApplicationError(
                "This report has already left the pending review queue.",
                code="report_not_pending",
                status_code=409,
            )

        now = datetime.now(UTC)
        final_priority = payload.final_priority if payload.decision != "invalid" else None
        priority_conflict = bool(
            final_priority is not None
            and report.suggested_priority is not None
            and final_priority != report.suggested_priority
        )
        report.verification_status = payload.decision
        report.final_priority = final_priority
        report.updated_at = now
        if payload.decision == "invalid":
            report.status = "closed"
            report.closed_at = now
        else:
            report.status = "under_review"

        review = ReportReview(
            report_id=report.report_id,
            reviewed_by_staff_id=reviewer_id,
            priority_conflict=priority_conflict,
            location_accurate=payload.location_accurate,
            possible_duplicate=payload.possible_duplicate,
            callback_needed=payload.callback_needed,
            decision=payload.decision,
            notes=payload.notes,
            reviewed_at=now,
        )
        event_details = {
            "decision": payload.decision,
            "final_priority": final_priority,
            "priority_conflict": priority_conflict,
            "location_accurate": payload.location_accurate,
            "possible_duplicate": payload.possible_duplicate,
            "callback_needed": payload.callback_needed,
        }
        self._database.add_all(
            [
                review,
                ReportEvent(
                    report_id=report.report_id,
                    actor_user_id=reviewer_id,
                    event_type="report.reviewed",
                    event_data=json.dumps(event_details),
                    created_at=now,
                ),
                AuditLog(
                    actor_user_id=reviewer_id,
                    action="report.review.completed",
                    entity_type="report",
                    entity_id=report.report_id,
                    details=json.dumps(event_details),
                    ip_address=ip_address,
                ),
            ]
        )
        await self._database.commit()
        return AdminReportReviewResult(
            report_id=report.report_id,
            decision=payload.decision,
            verification_status=cast(VerificationStatusValue, report.verification_status),
            report_status=cast(ReportStatusValue, report.status),
            final_priority=final_priority,
            reviewed_at=now,
        )

    @staticmethod
    def _build_conditions(filters: AdminReportFilters) -> list[ColumnElement[bool]]:
        conditions: list[ColumnElement[bool]] = [Report.deleted_at.is_(None)]
        if filters.search:
            escaped = (
                filters.search.strip().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
            )
            if escaped:
                pattern = f"%{escaped}%"
                conditions.append(
                    or_(
                        sa_cast(Report.report_id, String).ilike(pattern, escape="\\"),
                        Report.description_original.ilike(pattern, escape="\\"),
                        IncidentType.code.ilike(pattern, escape="\\"),
                        IncidentType.name.ilike(pattern, escape="\\"),
                        ReportLocation.landmark.ilike(pattern, escape="\\"),
                    )
                )
        if filters.statuses:
            conditions.append(Report.status.in_(filters.statuses))
        if filters.verification_statuses:
            conditions.append(Report.verification_status.in_(filters.verification_statuses))
        if filters.priorities:
            conditions.append(
                func.coalesce(
                    Report.final_priority,
                    Report.suggested_priority,
                    IncidentType.default_priority,
                ).in_(filters.priorities)
            )
        if filters.sources:
            conditions.append(Report.source.in_(filters.sources))
        if filters.incident_statuses:
            conditions.append(
                and_(
                    Report.incident_id.is_not(None),
                    Incident.status.in_(filters.incident_statuses),
                )
            )
        if filters.incident_type_id is not None:
            conditions.append(Report.incident_type_id == filters.incident_type_id)
        return conditions

    @staticmethod
    def _to_list_item(
        report: Report,
        incident_type: IncidentType,
        location: ReportLocation | None,
        incident: Incident | None,
    ) -> AdminReportListItem:
        effective_priority = (
            report.final_priority or report.suggested_priority or incident_type.default_priority
        )
        return AdminReportListItem(
            report_id=report.report_id,
            client_report_id=report.client_report_id,
            incident_type=IncidentTypeSummary(
                incident_type_id=incident_type.incident_type_id,
                code=incident_type.code,
                name=incident_type.name,
            ),
            incident=(
                IncidentSummary(
                    incident_id=incident.incident_id,
                    priority=cast(PriorityValue, incident.priority),
                    status=cast(IncidentStatusValue, incident.status),
                    summary=incident.summary,
                )
                if incident is not None
                else None
            ),
            source=cast(ReportSourceValue, report.source),
            manual_intake_channel=cast(
                ManualIntakeChannelValue | None, report.manual_intake_channel
            ),
            description_original=report.description_original,
            original_language=report.original_language,
            people_need_help=report.people_need_help,
            additional_assistance=report.additional_assistance,
            immediate_danger=report.immediate_danger,
            suggested_priority=cast(PriorityValue | None, report.suggested_priority),
            final_priority=cast(PriorityValue | None, report.final_priority),
            effective_priority=cast(PriorityValue, effective_priority),
            verification_status=cast(VerificationStatusValue, report.verification_status),
            status=cast(ReportStatusValue, report.status),
            location=(
                ReportLocationResponse(
                    latitude=(float(location.latitude) if location.latitude is not None else None),
                    longitude=(
                        float(location.longitude) if location.longitude is not None else None
                    ),
                    accuracy_meters=(
                        float(location.accuracy_meters)
                        if location.accuracy_meters is not None
                        else None
                    ),
                    landmark=location.landmark,
                    source=cast(Literal["gps", "manual"], location.source),
                    captured_at=location.captured_at,
                )
                if location is not None
                else None
            ),
            received_at=report.received_at,
            updated_at=report.updated_at,
            closed_at=report.closed_at,
        )

    async def _list_attachments(self, report_id: uuid.UUID) -> list[ReportAttachmentResponse]:
        result = await self._database.execute(
            select(ReportAttachment)
            .where(
                ReportAttachment.report_id == report_id,
                ReportAttachment.deleted_at.is_(None),
            )
            .order_by(ReportAttachment.created_at.desc())
        )
        return [
            ReportAttachmentResponse(
                attachment_id=item.attachment_id,
                media_type=cast(Literal["image", "video"], item.media_type),
                content_type=item.content_type,
                size_bytes=item.size_bytes,
                created_at=item.created_at,
            )
            for item in result.scalars()
        ]

    async def _list_translations(self, report_id: uuid.UUID) -> list[ReportTranslationResponse]:
        result = await self._database.execute(
            select(ReportTranslation)
            .where(ReportTranslation.report_id == report_id)
            .order_by(ReportTranslation.created_at.desc())
        )
        return [
            ReportTranslationResponse(
                translation_id=item.translation_id,
                source_language=item.source_language,
                target_language=item.target_language,
                translated_text=item.translated_text,
                model_name=item.model_name,
                model_version=item.model_version,
                confidence=float(item.confidence) if item.confidence is not None else None,
                created_at=item.created_at,
            )
            for item in result.scalars()
        ]

    async def _list_priority_assessments(
        self, report_id: uuid.UUID
    ) -> list[PriorityAssessmentResponse]:
        result = await self._database.execute(
            select(PriorityAssessment)
            .where(PriorityAssessment.report_id == report_id)
            .order_by(PriorityAssessment.created_at.desc())
        )
        return [
            PriorityAssessmentResponse(
                assessment_id=item.assessment_id,
                suggested_priority=cast(PriorityValue, item.suggested_priority),
                confidence=float(item.confidence),
                model_name=item.model_name,
                model_version=item.model_version,
                explanation=item.explanation,
                created_at=item.created_at,
            )
            for item in result.scalars()
        ]

    async def _list_reviews(self, report_id: uuid.UUID) -> list[ReportReviewResponse]:
        result = await self._database.execute(
            select(ReportReview)
            .where(ReportReview.report_id == report_id)
            .order_by(ReportReview.reviewed_at.desc())
        )
        return [
            ReportReviewResponse(
                review_id=item.review_id,
                reviewed_by_staff_id=item.reviewed_by_staff_id,
                priority_conflict=item.priority_conflict,
                location_accurate=item.location_accurate,
                possible_duplicate=item.possible_duplicate,
                callback_needed=item.callback_needed,
                decision=item.decision,
                notes=item.notes,
                reviewed_at=item.reviewed_at,
            )
            for item in result.scalars()
        ]
