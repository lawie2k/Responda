import asyncio
import uuid
from datetime import UTC, datetime
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock

from pytest import raises
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ApplicationError
from app.models import AuditLog, ResponseUnit
from app.schemas.admin_response_units import (
    AdminResponseUnitCreateRequest,
    AdminResponseUnitUpdateRequest,
)
from app.services.admin_response_units import (
    AdminResponseUnitFilters,
    AdminResponseUnitService,
)


def test_list_response_units_maps_counts_locations_and_filters() -> None:
    now = datetime(2026, 10, 16, 5, 0, tzinfo=UTC)
    unit = ResponseUnit(
        unit_id=uuid.uuid4(),
        name="Rescue Alpha",
        unit_type="Search and rescue",
        contact="Operations radio",
        status="available",
        current_latitude=Decimal("7.575000"),
        current_longitude=Decimal("125.950000"),
        location_updated_at=now,
        created_at=now,
        updated_at=now,
    )
    count_result = MagicMock()
    count_result.scalar_one.return_value = 1
    counts_result = MagicMock()
    counts_result.all.return_value = [
        ("available", 1),
        ("assigned", 2),
        ("responding", 1),
        ("offline", 1),
    ]
    list_result = MagicMock()
    list_result.scalars.return_value = [unit]
    database = MagicMock(spec=AsyncSession)
    database.execute = AsyncMock(side_effect=[count_result, counts_result, list_result])
    service = AdminResponseUnitService(database)

    response = asyncio.run(
        service.list_units(
            AdminResponseUnitFilters(
                page=1,
                page_size=20,
                search="rescue",
                statuses=("available",),
            )
        )
    )

    assert response.total == 1
    assert response.total_pages == 1
    assert response.counts.total == 5
    assert response.counts.available == 1
    assert response.counts.assigned == 2
    assert response.counts.responding == 1
    assert response.counts.offline == 1
    assert response.items[0].unit_id == unit.unit_id
    assert response.items[0].current_latitude == 7.575
    assert response.items[0].current_longitude == 125.95
    statements = [str(call.args[0]) for call in database.execute.await_args_list]
    assert all("response_units.deleted_at IS NULL" in statement for statement in statements)
    assert "response_units.status IN" in statements[0]
    assert "lower(response_units.name) LIKE lower" in statements[0]


def scalar_result(value: object | None) -> MagicMock:
    result = MagicMock()
    result.scalar_one_or_none.return_value = value
    return result


def database_mock(*results: object | None) -> MagicMock:
    database = MagicMock(spec=AsyncSession)
    database.execute = AsyncMock(side_effect=[scalar_result(value) for value in results])
    database.flush = AsyncMock()
    database.commit = AsyncMock()
    database.rollback = AsyncMock()
    return database


def response_unit() -> ResponseUnit:
    now = datetime(2026, 10, 16, 5, 0, tzinfo=UTC)
    return ResponseUnit(
        unit_id=uuid.uuid4(),
        name="Rescue Alpha",
        unit_type="Search and rescue",
        contact="Operations radio",
        status="available",
        created_at=now,
        updated_at=now,
    )


def test_create_response_unit_starts_available_and_writes_audit_atomically() -> None:
    database = database_mock(None)
    service = AdminResponseUnitService(database)
    staff_id = uuid.uuid4()

    result = asyncio.run(
        service.create_unit(
            staff_id=staff_id,
            payload=AdminResponseUnitCreateRequest(
                name="  Rescue Bravo  ",
                unit_type="  Search and rescue  ",
                contact="  Operations radio 2  ",
            ),
            ip_address="127.0.0.1",
        )
    )

    added = [call.args[0] for call in database.add.call_args_list]
    unit = next(item for item in added if isinstance(item, ResponseUnit))
    audit = next(item for item in added if isinstance(item, AuditLog))
    assert unit.name == "Rescue Bravo"
    assert unit.status == "available"
    assert result.unit_id == unit.unit_id
    assert audit.action == "response_unit.created"
    assert audit.actor_user_id == staff_id
    assert audit.details is not None and unit.contact not in audit.details
    database.flush.assert_awaited_once()
    database.commit.assert_awaited_once()


def test_update_response_unit_locks_record_and_audits_changed_fields() -> None:
    unit = response_unit()
    database = database_mock(unit)
    service = AdminResponseUnitService(database)

    result = asyncio.run(
        service.update_unit(
            unit.unit_id,
            staff_id=uuid.uuid4(),
            payload=AdminResponseUnitUpdateRequest(
                expected_updated_at=unit.updated_at,
                contact="Updated dispatch radio",
            ),
            ip_address="127.0.0.1",
        )
    )

    audit = database.add.call_args.args[0]
    statement = str(database.execute.await_args_list[0].args[0])
    assert isinstance(audit, AuditLog)
    assert "FOR UPDATE" in statement
    assert unit.contact == "Updated dispatch radio"
    assert unit.status == "available"
    assert result.contact == "Updated dispatch radio"
    assert audit.action == "response_unit.updated"
    assert audit.details is not None and "contact" in audit.details
    assert "Updated dispatch radio" not in audit.details
    database.commit.assert_awaited_once()


def test_stale_response_unit_update_is_rejected() -> None:
    unit = response_unit()
    database = database_mock(unit)
    service = AdminResponseUnitService(database)

    with raises(ApplicationError) as error:
        asyncio.run(
            service.update_unit(
                unit.unit_id,
                staff_id=uuid.uuid4(),
                payload=AdminResponseUnitUpdateRequest(
                    expected_updated_at=unit.updated_at.replace(second=1),
                    contact="Updated dispatch radio",
                ),
                ip_address="127.0.0.1",
            )
        )

    assert error.value.code == "response_unit_update_conflict"
    database.add.assert_not_called()
    database.commit.assert_not_awaited()


def test_duplicate_response_unit_name_is_rejected() -> None:
    database = database_mock(uuid.uuid4())
    service = AdminResponseUnitService(database)

    with raises(ApplicationError) as error:
        asyncio.run(
            service.create_unit(
                staff_id=uuid.uuid4(),
                payload=AdminResponseUnitCreateRequest(
                    name="Rescue Alpha",
                    unit_type="Search and rescue",
                    contact="Operations radio",
                ),
                ip_address="127.0.0.1",
            )
        )

    assert error.value.code == "response_unit_name_conflict"
    database.add.assert_not_called()
    database.commit.assert_not_awaited()
