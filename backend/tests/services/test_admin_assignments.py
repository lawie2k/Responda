import asyncio
import json
import uuid
from datetime import UTC, datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

from pytest import raises
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ApplicationError
from app.models import AuditLog, Incident, ReportEvent, ResponseAssignment, ResponseUnit
from app.schemas.admin_assignments import (
    AdminAssignmentCreateRequest,
    AdminAssignmentTransitionRequest,
)
from app.services.admin_assignments import AdminAssignmentService

INCIDENT_ID = uuid.UUID("00000000-0000-0000-0000-000000000601")
UNIT_ID = uuid.UUID("00000000-0000-0000-0000-000000000602")
ASSIGNMENT_ID = uuid.UUID("00000000-0000-0000-0000-000000000603")
STAFF_ID = uuid.UUID("00000000-0000-0000-0000-000000000604")
REPORT_ID = uuid.UUID("00000000-0000-0000-0000-000000000605")
UPDATED_AT = datetime(2026, 10, 16, 8, 0, tzinfo=UTC)


def database_mock(*execute_results: MagicMock) -> MagicMock:
    database = MagicMock(spec=AsyncSession)
    database.execute = AsyncMock(side_effect=execute_results)
    database.flush = AsyncMock()
    database.commit = AsyncMock()
    database.rollback = AsyncMock()
    return database


def scalar_result(value: object) -> MagicMock:
    result = MagicMock()
    result.scalar_one_or_none.return_value = value
    result.scalar_one.return_value = value
    return result


def scalars_result(values: list[object]) -> MagicMock:
    result = MagicMock()
    result.scalars.return_value = values
    return result


def all_result(values: list[object]) -> MagicMock:
    result = MagicMock()
    result.all.return_value = values
    return result


def row_result(value: object) -> MagicMock:
    result = MagicMock()
    result.one_or_none.return_value = value
    return result


def incident(*, status: str = "open", updated_at: datetime = UPDATED_AT) -> Incident:
    return Incident(
        incident_id=INCIDENT_ID,
        incident_type_id=uuid.uuid4(),
        created_by_staff_id=STAFF_ID,
        summary="Confirmed incident",
        priority="high",
        status=status,
        opened_at=UPDATED_AT,
        updated_at=updated_at,
    )


def unit(*, status: str = "available") -> ResponseUnit:
    return ResponseUnit(
        unit_id=UNIT_ID,
        name="Rescue Alpha",
        unit_type="Search and rescue",
        contact="Operations radio",
        status=status,
        created_at=UPDATED_AT,
        updated_at=UPDATED_AT,
    )


def assignment(
    *,
    status: str = "assigned",
    updated_at: datetime = UPDATED_AT,
) -> ResponseAssignment:
    return ResponseAssignment(
        assignment_id=ASSIGNMENT_ID,
        incident_id=INCIDENT_ID,
        unit_id=UNIT_ID,
        assigned_by_staff_id=STAFF_ID,
        status=status,
        assigned_at=UPDATED_AT,
        updated_at=updated_at,
    )


def transition_database(
    assignment_record: ResponseAssignment,
    incident_record: Incident,
    unit_record: ResponseUnit,
    *,
    active_statuses: list[str],
) -> MagicMock:
    return database_mock(
        row_result(
            SimpleNamespace(
                incident_id=assignment_record.incident_id,
                unit_id=assignment_record.unit_id,
            )
        ),
        scalar_result(incident_record),
        scalar_result(unit_record),
        scalar_result(assignment_record),
        scalars_result(active_statuses),
        scalars_result([REPORT_ID]),
    )


def test_list_assignments_returns_non_deleted_units_for_the_incident() -> None:
    assignment_record = assignment()
    unit_record = unit(status="assigned")
    database = database_mock(
        scalar_result(INCIDENT_ID),
        scalar_result(1),
        all_result([(assignment_record, unit_record)]),
    )
    service = AdminAssignmentService(database)

    result = asyncio.run(service.list_assignments(INCIDENT_ID, page=1, page_size=20))

    assert result.total == 1
    assert result.items[0].assignment_id == ASSIGNMENT_ID
    assert result.items[0].unit.status == "assigned"
    count_statement = database.execute.await_args_list[1].args[0]
    assert "response_assignments.deleted_at IS NULL" in str(count_statement)
    assert "response_units.deleted_at IS NULL" in str(count_statement)


def test_create_assignment_updates_incident_unit_and_history_atomically() -> None:
    incident_record = incident()
    unit_record = unit()
    database = database_mock(
        scalar_result(incident_record),
        scalar_result(unit_record),
        scalar_result(None),
        scalars_result([REPORT_ID]),
    )
    service = AdminAssignmentService(database)

    result = asyncio.run(
        service.create_assignment(
            INCIDENT_ID,
            staff_id=STAFF_ID,
            payload=AdminAssignmentCreateRequest(
                unit_id=UNIT_ID,
                expected_incident_updated_at=UPDATED_AT,
            ),
            ip_address="127.0.0.1",
        )
    )

    assert result.assignment.status == "assigned"
    assert result.assignment.unit.status == "assigned"
    assert result.incident_status == "dispatched"
    assert incident_record.status == "dispatched"
    assert unit_record.status == "assigned"
    history = database.add_all.call_args.args[0]
    event = next(item for item in history if isinstance(item, ReportEvent))
    audit = next(item for item in history if isinstance(item, AuditLog))
    assert event.event_type == "response.assigned"
    assert audit.action == "response_assignment.created"
    assert "contact" not in json.loads(audit.details or "{}")
    database.commit.assert_awaited_once()


def test_create_assignment_rejects_a_stale_incident() -> None:
    incident_record = incident(updated_at=datetime(2026, 10, 16, 9, 0, tzinfo=UTC))
    database = database_mock(scalar_result(incident_record))
    service = AdminAssignmentService(database)

    with raises(ApplicationError) as error:
        asyncio.run(
            service.create_assignment(
                INCIDENT_ID,
                staff_id=STAFF_ID,
                payload=AdminAssignmentCreateRequest(
                    unit_id=UNIT_ID,
                    expected_incident_updated_at=UPDATED_AT,
                ),
                ip_address="127.0.0.1",
            )
        )

    assert error.value.code == "assignment_incident_conflict"
    database.commit.assert_not_awaited()


def test_create_assignment_rejects_an_unavailable_unit() -> None:
    database = database_mock(
        scalar_result(incident()),
        scalar_result(unit(status="responding")),
    )
    service = AdminAssignmentService(database)

    with raises(ApplicationError) as error:
        asyncio.run(
            service.create_assignment(
                INCIDENT_ID,
                staff_id=STAFF_ID,
                payload=AdminAssignmentCreateRequest(
                    unit_id=UNIT_ID,
                    expected_incident_updated_at=UPDATED_AT,
                ),
                ip_address="127.0.0.1",
            )
        )

    assert error.value.code == "response_unit_unavailable"
    database.commit.assert_not_awaited()


def test_acknowledge_assignment_keeps_unit_assigned_and_incident_dispatched() -> None:
    assignment_record = assignment(status="assigned")
    incident_record = incident(status="dispatched")
    unit_record = unit(status="assigned")
    database = transition_database(
        assignment_record,
        incident_record,
        unit_record,
        active_statuses=["acknowledged"],
    )
    service = AdminAssignmentService(database)

    result = asyncio.run(
        service.transition_assignment(
            ASSIGNMENT_ID,
            staff_id=STAFF_ID,
            payload=AdminAssignmentTransitionRequest(
                expected_updated_at=UPDATED_AT,
                status="acknowledged",
            ),
            ip_address="127.0.0.1",
        )
    )

    assert result.assignment.status == "acknowledged"
    assert result.assignment.acknowledged_at is not None
    assert result.assignment.unit.status == "assigned"
    assert result.incident_status == "dispatched"


def test_responding_assignment_moves_unit_and_incident_to_responding() -> None:
    assignment_record = assignment(status="acknowledged")
    incident_record = incident(status="dispatched")
    unit_record = unit(status="assigned")
    database = transition_database(
        assignment_record,
        incident_record,
        unit_record,
        active_statuses=["responding"],
    )
    service = AdminAssignmentService(database)

    result = asyncio.run(
        service.transition_assignment(
            ASSIGNMENT_ID,
            staff_id=STAFF_ID,
            payload=AdminAssignmentTransitionRequest(
                expected_updated_at=UPDATED_AT,
                status="responding",
            ),
            ip_address="127.0.0.1",
        )
    )

    assert result.assignment.responding_at is not None
    assert result.assignment.unit.status == "responding"
    assert result.incident_status == "responding"


def test_completing_the_last_active_assignment_resolves_incident() -> None:
    assignment_record = assignment(status="responding")
    incident_record = incident(status="responding")
    unit_record = unit(status="responding")
    database = transition_database(
        assignment_record,
        incident_record,
        unit_record,
        active_statuses=[],
    )
    service = AdminAssignmentService(database)

    result = asyncio.run(
        service.transition_assignment(
            ASSIGNMENT_ID,
            staff_id=STAFF_ID,
            payload=AdminAssignmentTransitionRequest(
                expected_updated_at=UPDATED_AT,
                status="completed",
            ),
            ip_address="127.0.0.1",
        )
    )

    assert result.assignment.completed_at is not None
    assert result.assignment.unit.status == "available"
    assert result.incident_status == "resolved"
    assert incident_record.resolved_at is not None


def test_completing_one_assignment_keeps_incident_active_for_other_team() -> None:
    assignment_record = assignment(status="responding")
    incident_record = incident(status="responding")
    unit_record = unit(status="responding")
    database = transition_database(
        assignment_record,
        incident_record,
        unit_record,
        active_statuses=["responding"],
    )
    service = AdminAssignmentService(database)

    result = asyncio.run(
        service.transition_assignment(
            ASSIGNMENT_ID,
            staff_id=STAFF_ID,
            payload=AdminAssignmentTransitionRequest(
                expected_updated_at=UPDATED_AT,
                status="completed",
            ),
            ip_address="127.0.0.1",
        )
    )

    assert result.assignment.unit.status == "available"
    assert result.incident_status == "responding"
    assert incident_record.resolved_at is None


def test_cancelling_the_last_active_assignment_reopens_incident() -> None:
    assignment_record = assignment(status="acknowledged")
    incident_record = incident(status="dispatched")
    unit_record = unit(status="assigned")
    database = transition_database(
        assignment_record,
        incident_record,
        unit_record,
        active_statuses=[],
    )
    service = AdminAssignmentService(database)

    result = asyncio.run(
        service.transition_assignment(
            ASSIGNMENT_ID,
            staff_id=STAFF_ID,
            payload=AdminAssignmentTransitionRequest(
                expected_updated_at=UPDATED_AT,
                status="cancelled",
            ),
            ip_address="127.0.0.1",
        )
    )

    assert result.assignment.cancelled_at is not None
    assert result.assignment.unit.status == "available"
    assert result.incident_status == "open"


def test_transition_rejects_skipping_acknowledgement() -> None:
    assignment_record = assignment(status="assigned")
    database = database_mock(
        row_result(SimpleNamespace(incident_id=INCIDENT_ID, unit_id=UNIT_ID)),
        scalar_result(incident(status="dispatched")),
        scalar_result(unit(status="assigned")),
        scalar_result(assignment_record),
    )
    service = AdminAssignmentService(database)

    with raises(ApplicationError) as error:
        asyncio.run(
            service.transition_assignment(
                ASSIGNMENT_ID,
                staff_id=STAFF_ID,
                payload=AdminAssignmentTransitionRequest(
                    expected_updated_at=UPDATED_AT,
                    status="responding",
                ),
                ip_address="127.0.0.1",
            )
        )

    assert error.value.code == "assignment_transition_invalid"
    database.commit.assert_not_awaited()


def test_transition_rejects_a_stale_assignment() -> None:
    assignment_record = assignment(
        status="assigned",
        updated_at=datetime(2026, 10, 16, 9, 0, tzinfo=UTC),
    )
    database = database_mock(
        row_result(SimpleNamespace(incident_id=INCIDENT_ID, unit_id=UNIT_ID)),
        scalar_result(incident(status="dispatched")),
        scalar_result(unit(status="assigned")),
        scalar_result(assignment_record),
    )
    service = AdminAssignmentService(database)

    with raises(ApplicationError) as error:
        asyncio.run(
            service.transition_assignment(
                ASSIGNMENT_ID,
                staff_id=STAFF_ID,
                payload=AdminAssignmentTransitionRequest(
                    expected_updated_at=UPDATED_AT,
                    status="acknowledged",
                ),
                ip_address="127.0.0.1",
            )
        )

    assert error.value.code == "assignment_update_conflict"
    database.commit.assert_not_awaited()
