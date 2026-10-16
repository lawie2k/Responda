import json
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from math import ceil
from typing import cast

from sqlalchemy import String, func, or_, select
from sqlalchemy import cast as sa_cast
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.sql.elements import ColumnElement

from app.core.exceptions import ApplicationError
from app.models import AuditLog, ResponseUnit
from app.schemas.admin_response_units import (
    AdminResponseUnitCounts,
    AdminResponseUnitCreateRequest,
    AdminResponseUnitListItem,
    AdminResponseUnitListResponse,
    AdminResponseUnitUpdateRequest,
    ResponseUnitStatusValue,
)


@dataclass(frozen=True, slots=True)
class AdminResponseUnitFilters:
    page: int
    page_size: int
    search: str | None = None
    statuses: tuple[str, ...] = ()


class AdminResponseUnitService:
    def __init__(self, database: AsyncSession) -> None:
        self._database = database

    async def list_units(self, filters: AdminResponseUnitFilters) -> AdminResponseUnitListResponse:
        conditions: list[ColumnElement[bool]] = [ResponseUnit.deleted_at.is_(None)]
        if filters.search:
            escaped = (
                filters.search.strip().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
            )
            if escaped:
                pattern = f"%{escaped}%"
                conditions.append(
                    or_(
                        sa_cast(ResponseUnit.unit_id, String).ilike(pattern, escape="\\"),
                        ResponseUnit.name.ilike(pattern, escape="\\"),
                        ResponseUnit.unit_type.ilike(pattern, escape="\\"),
                        ResponseUnit.contact.ilike(pattern, escape="\\"),
                    )
                )
        if filters.statuses:
            conditions.append(ResponseUnit.status.in_(filters.statuses))

        count_result = await self._database.execute(
            select(func.count(ResponseUnit.unit_id)).where(*conditions)
        )
        total = int(count_result.scalar_one())
        counts_result = await self._database.execute(
            select(ResponseUnit.status, func.count(ResponseUnit.unit_id))
            .where(ResponseUnit.deleted_at.is_(None))
            .group_by(ResponseUnit.status)
        )
        count_by_status = {str(status): int(count) for status, count in counts_result.all()}
        list_result = await self._database.execute(
            select(ResponseUnit)
            .where(*conditions)
            .order_by(ResponseUnit.name.asc(), ResponseUnit.unit_id.asc())
            .offset((filters.page - 1) * filters.page_size)
            .limit(filters.page_size)
        )
        items = [
            AdminResponseUnitListItem(
                unit_id=unit.unit_id,
                name=unit.name,
                unit_type=unit.unit_type,
                contact=unit.contact,
                status=cast(ResponseUnitStatusValue, unit.status),
                current_latitude=(
                    float(unit.current_latitude) if unit.current_latitude is not None else None
                ),
                current_longitude=(
                    float(unit.current_longitude) if unit.current_longitude is not None else None
                ),
                location_updated_at=unit.location_updated_at,
                created_at=unit.created_at,
                updated_at=unit.updated_at,
            )
            for unit in list_result.scalars()
        ]
        counts = AdminResponseUnitCounts(
            total=sum(count_by_status.values()),
            available=count_by_status.get("available", 0),
            assigned=count_by_status.get("assigned", 0),
            responding=count_by_status.get("responding", 0),
            offline=count_by_status.get("offline", 0),
        )
        return AdminResponseUnitListResponse(
            items=items,
            counts=counts,
            total=total,
            page=filters.page,
            page_size=filters.page_size,
            total_pages=ceil(total / filters.page_size) if total else 0,
        )

    async def create_unit(
        self,
        *,
        staff_id: uuid.UUID,
        payload: AdminResponseUnitCreateRequest,
        ip_address: str,
    ) -> AdminResponseUnitListItem:
        await self._ensure_name_available(payload.name)
        now = datetime.now(UTC)
        unit = ResponseUnit(
            unit_id=uuid.uuid4(),
            name=payload.name,
            unit_type=payload.unit_type,
            contact=payload.contact,
            status="available",
            created_at=now,
            updated_at=now,
        )
        self._database.add(unit)
        self._database.add(
            AuditLog(
                actor_user_id=staff_id,
                action="response_unit.created",
                entity_type="response_unit",
                entity_id=unit.unit_id,
                details=json.dumps(
                    {
                        "unit_id": str(unit.unit_id),
                        "operation": "created",
                        "initial_status": "available",
                    }
                ),
                ip_address=ip_address,
                created_at=now,
            )
        )
        await self._commit_roster_write()
        return self._to_item(unit)

    async def update_unit(
        self,
        unit_id: uuid.UUID,
        *,
        staff_id: uuid.UUID,
        payload: AdminResponseUnitUpdateRequest,
        ip_address: str,
    ) -> AdminResponseUnitListItem:
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
        if unit.updated_at != payload.expected_updated_at:
            raise ApplicationError(
                "This response unit changed after it was opened. Reload it before saving.",
                code="response_unit_update_conflict",
                status_code=409,
            )

        changed_fields: list[str] = []
        if payload.name is not None and payload.name != unit.name:
            await self._ensure_name_available(payload.name, exclude_unit_id=unit.unit_id)
            unit.name = payload.name
            changed_fields.append("name")
        if payload.unit_type is not None and payload.unit_type != unit.unit_type:
            unit.unit_type = payload.unit_type
            changed_fields.append("unit_type")
        if payload.contact is not None and payload.contact != unit.contact:
            unit.contact = payload.contact
            changed_fields.append("contact")
        if not changed_fields:
            raise ApplicationError(
                "No response-unit changes were provided.",
                code="response_unit_unchanged",
                status_code=409,
            )

        now = datetime.now(UTC)
        unit.updated_at = now
        self._database.add(
            AuditLog(
                actor_user_id=staff_id,
                action="response_unit.updated",
                entity_type="response_unit",
                entity_id=unit.unit_id,
                details=json.dumps(
                    {
                        "unit_id": str(unit.unit_id),
                        "operation": "updated",
                        "changed_fields": changed_fields,
                    }
                ),
                ip_address=ip_address,
                created_at=now,
            )
        )
        await self._commit_roster_write()
        return self._to_item(unit)

    async def _ensure_name_available(
        self,
        name: str,
        *,
        exclude_unit_id: uuid.UUID | None = None,
    ) -> None:
        statement = select(ResponseUnit.unit_id).where(
            func.lower(ResponseUnit.name) == name.lower()
        )
        if exclude_unit_id is not None:
            statement = statement.where(ResponseUnit.unit_id != exclude_unit_id)
        result = await self._database.execute(statement)
        if result.scalar_one_or_none() is not None:
            raise ApplicationError(
                "A response unit with this name already exists.",
                code="response_unit_name_conflict",
                status_code=409,
            )

    async def _commit_roster_write(self) -> None:
        try:
            await self._database.flush()
            await self._database.commit()
        except IntegrityError as error:
            await self._database.rollback()
            raise ApplicationError(
                "A response unit with this name already exists.",
                code="response_unit_name_conflict",
                status_code=409,
            ) from error

    @staticmethod
    def _to_item(unit: ResponseUnit) -> AdminResponseUnitListItem:
        return AdminResponseUnitListItem(
            unit_id=unit.unit_id,
            name=unit.name,
            unit_type=unit.unit_type,
            contact=unit.contact,
            status=cast(ResponseUnitStatusValue, unit.status),
            current_latitude=(
                float(unit.current_latitude) if unit.current_latitude is not None else None
            ),
            current_longitude=(
                float(unit.current_longitude) if unit.current_longitude is not None else None
            ),
            location_updated_at=unit.location_updated_at,
            created_at=unit.created_at,
            updated_at=unit.updated_at,
        )
