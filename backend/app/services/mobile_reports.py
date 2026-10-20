import json
import uuid
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ApplicationError
from app.models import AuditLog, IncidentType, Report, ReportEvent, ReportLocation, User
from app.schemas.mobile_reports import MobileReportCreateRequest, MobileReportCreateResponse


class MobileReportService:
    def __init__(self, database: AsyncSession) -> None:
        self._database = database

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
