import json
import uuid
from datetime import UTC, datetime
from math import ceil
from typing import cast

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ApplicationError
from app.models import AuditLog, Incident, Report, ReportEvent, ResponseAssignment, ResponseUnit
from app.schemas.admin_assignments import (
    AdminAssignmentCreateRequest,
    AdminAssignmentListItem,
    AdminAssignmentListResponse,
    AdminAssignmentMutationResult,
    AdminAssignmentTransitionRequest,
    AdminAssignmentUnitSummary,
    AssignmentStatusValue,
)
from app.schemas.admin_reports import IncidentStatusValue
from app.schemas.admin_response_units import ResponseUnitStatusValue

ACTIVE_ASSIGNMENT_STATUSES = {"assigned", "acknowledged", "responding"}
ALLOWED_TRANSITIONS = {
    "assigned": {"acknowledged", "cancelled"},
    "acknowledged": {"responding", "cancelled"},
    "responding": {"completed", "cancelled"},
}


class AdminAssignmentService:
    def __init__(self, database: AsyncSession) -> None:
        self._database = database

    async def list_assignments(
        self,
        incident_id: uuid.UUID,
        *,
        page: int,
        page_size: int,
    ) -> AdminAssignmentListResponse:
        incident_result = await self._database.execute(
            select(Incident.incident_id).where(
                Incident.incident_id == incident_id,
                Incident.deleted_at.is_(None),
            )
        )
        if incident_result.scalar_one_or_none() is None:
            raise self._incident_not_found_error()

        conditions = (
            ResponseAssignment.incident_id == incident_id,
            ResponseAssignment.deleted_at.is_(None),
            ResponseUnit.deleted_at.is_(None),
        )
        count_result = await self._database.execute(
            select(func.count(ResponseAssignment.assignment_id))
            .join(ResponseUnit, ResponseUnit.unit_id == ResponseAssignment.unit_id)
            .where(*conditions)
        )
        total = int(count_result.scalar_one())
        list_result = await self._database.execute(
            select(ResponseAssignment, ResponseUnit)
            .join(ResponseUnit, ResponseUnit.unit_id == ResponseAssignment.unit_id)
            .where(*conditions)
            .order_by(
                ResponseAssignment.assigned_at.desc(),
                ResponseAssignment.assignment_id.desc(),
            )
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        return AdminAssignmentListResponse(
            items=[self._to_item(assignment, unit) for assignment, unit in list_result.all()],
            total=total,
            page=page,
            page_size=page_size,
            total_pages=ceil(total / page_size) if total else 0,
        )

    async def create_assignment(
        self,
        incident_id: uuid.UUID,
        *,
        staff_id: uuid.UUID,
        payload: AdminAssignmentCreateRequest,
        ip_address: str,
    ) -> AdminAssignmentMutationResult:
        incident = await self._lock_incident(incident_id)
        if incident.updated_at != payload.expected_incident_updated_at:
            raise ApplicationError(
                "This incident changed after it was opened. Reload it before assigning a unit.",
                code="assignment_incident_conflict",
                status_code=409,
            )
        if incident.status not in {"open", "dispatched", "responding"}:
            raise ApplicationError(
                "Response units cannot be assigned to a resolved or closed incident.",
                code="incident_not_assignable",
                status_code=409,
            )

        unit = await self._lock_unit(payload.unit_id)
        if unit.status != "available":
            raise ApplicationError(
                "This response unit is not currently available.",
                code="response_unit_unavailable",
                status_code=409,
            )
        active_result = await self._database.execute(
            select(ResponseAssignment.assignment_id)
            .where(
                ResponseAssignment.unit_id == unit.unit_id,
                ResponseAssignment.status.in_(ACTIVE_ASSIGNMENT_STATUSES),
                ResponseAssignment.deleted_at.is_(None),
            )
            .with_for_update()
        )
        if active_result.scalar_one_or_none() is not None:
            raise ApplicationError(
                "This response unit already has an active assignment.",
                code="response_unit_already_assigned",
                status_code=409,
            )

        now = datetime.now(UTC)
        assignment = ResponseAssignment(
            assignment_id=uuid.uuid4(),
            incident_id=incident.incident_id,
            unit_id=unit.unit_id,
            assigned_by_staff_id=staff_id,
            status="assigned",
            assigned_at=now,
            updated_at=now,
        )
        unit.status = "assigned"
        unit.updated_at = now
        if incident.status == "open":
            incident.status = "dispatched"
        incident.updated_at = now
        self._database.add(assignment)
        try:
            await self._add_history(
                assignment=assignment,
                staff_id=staff_id,
                action="response_assignment.created",
                event_type="response.assigned",
                ip_address=ip_address,
                now=now,
            )
            await self._database.flush()
            await self._database.commit()
        except IntegrityError as error:
            await self._database.rollback()
            raise ApplicationError(
                "This response unit already has an active assignment.",
                code="response_unit_already_assigned",
                status_code=409,
            ) from error
        return self._to_mutation_result(assignment, unit, incident)

    async def transition_assignment(
        self,
        assignment_id: uuid.UUID,
        *,
        staff_id: uuid.UUID,
        payload: AdminAssignmentTransitionRequest,
        ip_address: str,
    ) -> AdminAssignmentMutationResult:
        lookup_result = await self._database.execute(
            select(ResponseAssignment.incident_id, ResponseAssignment.unit_id).where(
                ResponseAssignment.assignment_id == assignment_id,
                ResponseAssignment.deleted_at.is_(None),
            )
        )
        identifiers = lookup_result.one_or_none()
        if identifiers is None:
            raise self._assignment_not_found_error()

        incident = await self._lock_incident(identifiers.incident_id)
        unit = await self._lock_unit(identifiers.unit_id)
        assignment_result = await self._database.execute(
            select(ResponseAssignment)
            .where(
                ResponseAssignment.assignment_id == assignment_id,
                ResponseAssignment.deleted_at.is_(None),
            )
            .with_for_update()
        )
        assignment = assignment_result.scalar_one_or_none()
        if assignment is None:
            raise self._assignment_not_found_error()
        if assignment.updated_at != payload.expected_updated_at:
            raise ApplicationError(
                "This assignment changed after it was opened. Reload it before updating.",
                code="assignment_update_conflict",
                status_code=409,
            )
        allowed_targets = ALLOWED_TRANSITIONS.get(assignment.status, set())
        if payload.status not in allowed_targets:
            raise ApplicationError(
                "This assignment cannot move to the requested status.",
                code="assignment_transition_invalid",
                status_code=409,
            )
        if incident.status in {"resolved", "closed"}:
            raise ApplicationError(
                "Assignments cannot be updated after the incident is resolved or closed.",
                code="incident_assignment_closed",
                status_code=409,
            )

        now = datetime.now(UTC)
        assignment.status = payload.status
        assignment.updated_at = now
        if payload.status == "acknowledged":
            assignment.acknowledged_at = now
            unit.status = "assigned"
        elif payload.status == "responding":
            assignment.responding_at = now
            unit.status = "responding"
        elif payload.status == "completed":
            assignment.completed_at = now
            unit.status = "available"
        else:
            assignment.cancelled_at = now
            unit.status = "available"
        unit.updated_at = now
        await self._database.flush()

        active_status_result = await self._database.execute(
            select(ResponseAssignment.status).where(
                ResponseAssignment.incident_id == incident.incident_id,
                ResponseAssignment.status.in_(ACTIVE_ASSIGNMENT_STATUSES),
                ResponseAssignment.deleted_at.is_(None),
            )
        )
        active_statuses = set(active_status_result.scalars())
        if "responding" in active_statuses:
            incident.status = "responding"
            incident.resolved_at = None
        elif active_statuses:
            incident.status = "dispatched"
            incident.resolved_at = None
        elif payload.status == "completed":
            incident.status = "resolved"
            incident.resolved_at = now
        else:
            incident.status = "open"
            incident.resolved_at = None
        incident.updated_at = now

        await self._add_history(
            assignment=assignment,
            staff_id=staff_id,
            action=f"response_assignment.{payload.status}",
            event_type=f"response.{payload.status}",
            ip_address=ip_address,
            now=now,
        )
        await self._database.commit()
        return self._to_mutation_result(assignment, unit, incident)

    async def _lock_incident(self, incident_id: uuid.UUID) -> Incident:
        result = await self._database.execute(
            select(Incident)
            .where(Incident.incident_id == incident_id, Incident.deleted_at.is_(None))
            .with_for_update()
        )
        incident = result.scalar_one_or_none()
        if incident is None:
            raise self._incident_not_found_error()
        return incident

    async def _lock_unit(self, unit_id: uuid.UUID) -> ResponseUnit:
        result = await self._database.execute(
            select(ResponseUnit)
            .where(ResponseUnit.unit_id == unit_id, ResponseUnit.deleted_at.is_(None))
            .with_for_update()
        )
        unit = result.scalar_one_or_none()
        if unit is None:
            raise ApplicationError(
                "The requested response unit was not found.",
                code="response_unit_not_found",
                status_code=404,
            )
        return unit

    async def _add_history(
        self,
        *,
        assignment: ResponseAssignment,
        staff_id: uuid.UUID,
        action: str,
        event_type: str,
        ip_address: str,
        now: datetime,
    ) -> None:
        report_result = await self._database.execute(
            select(Report.report_id).where(
                Report.incident_id == assignment.incident_id,
                Report.deleted_at.is_(None),
            )
        )
        report_ids = list(report_result.scalars())
        details = {
            "assignment_id": str(assignment.assignment_id),
            "incident_id": str(assignment.incident_id),
            "unit_id": str(assignment.unit_id),
            "status": assignment.status,
        }
        self._database.add_all(
            [
                ReportEvent(
                    report_id=report_id,
                    actor_user_id=staff_id,
                    event_type=event_type,
                    event_data=json.dumps(details),
                    created_at=now,
                )
                for report_id in report_ids
            ]
            + [
                AuditLog(
                    actor_user_id=staff_id,
                    action=action,
                    entity_type="response_assignment",
                    entity_id=assignment.assignment_id,
                    details=json.dumps(details),
                    ip_address=ip_address,
                    created_at=now,
                )
            ]
        )

    @staticmethod
    def _to_item(
        assignment: ResponseAssignment,
        unit: ResponseUnit,
    ) -> AdminAssignmentListItem:
        return AdminAssignmentListItem(
            assignment_id=assignment.assignment_id,
            incident_id=assignment.incident_id,
            unit=AdminAssignmentUnitSummary(
                unit_id=unit.unit_id,
                name=unit.name,
                unit_type=unit.unit_type,
                contact=unit.contact,
                status=cast(ResponseUnitStatusValue, unit.status),
            ),
            assigned_by_staff_id=assignment.assigned_by_staff_id,
            status=cast(AssignmentStatusValue, assignment.status),
            assigned_at=assignment.assigned_at,
            acknowledged_at=assignment.acknowledged_at,
            responding_at=assignment.responding_at,
            completed_at=assignment.completed_at,
            cancelled_at=assignment.cancelled_at,
            updated_at=assignment.updated_at,
        )

    @classmethod
    def _to_mutation_result(
        cls,
        assignment: ResponseAssignment,
        unit: ResponseUnit,
        incident: Incident,
    ) -> AdminAssignmentMutationResult:
        return AdminAssignmentMutationResult(
            assignment=cls._to_item(assignment, unit),
            incident_status=cast(IncidentStatusValue, incident.status),
            incident_updated_at=incident.updated_at,
        )

    @staticmethod
    def _incident_not_found_error() -> ApplicationError:
        return ApplicationError(
            "The requested incident was not found.",
            code="incident_not_found",
            status_code=404,
        )

    @staticmethod
    def _assignment_not_found_error() -> ApplicationError:
        return ApplicationError(
            "The requested response assignment was not found.",
            code="assignment_not_found",
            status_code=404,
        )
