import json
import uuid
from datetime import UTC, datetime
from math import ceil
from typing import Literal, cast

from sqlalchemy import func, or_, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.sql.elements import ColumnElement
from starlette.concurrency import run_in_threadpool

from app.core.exceptions import ApplicationError
from app.core.security import hash_password, normalize_email
from app.models import AuditLog, AuthSession, User
from app.models.enums import ADMINISTRATOR_ROLES
from app.schemas.admin_staff import StaffCreate, StaffItem, StaffList, StaffRevoke, StaffUpdate
from app.services.admin_auth import AuthenticatedAdmin


class AdminStaffService:
    def __init__(self, database: AsyncSession) -> None:
        self.database = database

    async def list_staff(
        self, *, page: int, page_size: int, search: str | None, active: bool | None
    ) -> StaffList:
        conditions: list[ColumnElement[bool]] = [
            User.deleted_at.is_(None),
            User.role.in_(ADMINISTRATOR_ROLES),
        ]
        if search and search.strip():
            escaped = search.strip().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
            conditions.append(
                or_(
                    User.full_name.ilike(f"%{escaped}%", escape="\\"),
                    User.email.ilike(f"%{escaped}%", escape="\\"),
                )
            )
        if active is not None:
            conditions.append(User.is_active == active)
        total = int(
            (
                await self.database.execute(
                    select(func.count()).select_from(User).where(*conditions)
                )
            ).scalar_one()
        )
        rows = (
            await self.database.execute(
                select(User)
                .where(*conditions)
                .order_by(User.role, User.full_name, User.user_id)
                .offset((page - 1) * page_size)
                .limit(page_size)
            )
        ).scalars()
        return StaffList(
            items=[self.item(user) for user in rows],
            total=total,
            page=page,
            page_size=page_size,
            total_pages=ceil(total / page_size),
        )

    async def _actor(self, current: AuthenticatedAdmin) -> None:
        # Serialize management and login against the same user row, then recheck session validity.
        user = (
            await self.database.execute(
                select(User)
                .where(User.user_id == current.user.user_id)
                .with_for_update()
                .execution_options(populate_existing=True)
            )
        ).scalar_one_or_none()
        session = (
            await self.database.execute(
                select(AuthSession)
                .where(
                    AuthSession.session_id == current.session.session_id,
                    AuthSession.user_id == current.user.user_id,
                )
                .execution_options(populate_existing=True)
            )
        ).scalar_one_or_none()
        now = datetime.now(UTC)
        if (
            user is None
            or user.role != "admin"
            or not user.is_active
            or user.deleted_at is not None
            or session is None
            or session.revoked_at is not None
            or self._utc(session.expires_at) <= now
        ):
            raise ApplicationError(
                "A valid Super Admin session is required.",
                code="staff_management_forbidden",
                status_code=403,
            )

    async def _target(self, user_id: uuid.UUID, expected: datetime) -> User:
        user = (
            await self.database.execute(
                select(User)
                .where(
                    User.user_id == user_id,
                    User.deleted_at.is_(None),
                    User.role.in_(ADMINISTRATOR_ROLES),
                )
                .with_for_update()
                .execution_options(populate_existing=True)
            )
        ).scalar_one_or_none()
        if user is None:
            raise ApplicationError(
                "Staff account not found.", code="staff_not_found", status_code=404
            )
        if user.role != "operations_admin":
            raise ApplicationError(
                "Super Admin accounts are protected.",
                code="protected_staff_account",
                status_code=403,
            )
        if self._utc(user.updated_at) != self._utc(expected):
            raise ApplicationError(
                "This account changed. Refresh before saving.",
                code="staff_update_conflict",
                status_code=409,
            )
        return user

    async def _email_available(self, email: str, user_id: uuid.UUID | None = None) -> None:
        query = select(User.user_id).where(func.lower(User.email) == email)
        if user_id is not None:
            query = query.where(User.user_id != user_id)
        if (await self.database.execute(query)).first() is not None:
            raise ApplicationError(
                "That email is already reserved by an account.",
                code="staff_email_conflict",
                status_code=409,
            )

    async def create_staff(self, current: AuthenticatedAdmin, payload: StaffCreate) -> StaffItem:
        await self._actor(current)
        email = normalize_email(payload.email)
        await self._email_available(email)
        now = datetime.now(UTC)
        user = User(
            user_id=uuid.uuid4(),
            full_name=payload.full_name,
            email=email,
            password_hash=await run_in_threadpool(
                hash_password, payload.password.get_secret_value()
            ),
            role="operations_admin",
            is_active=True,
            created_at=now,
            updated_at=now,
        )
        self.database.add(user)
        self._audit(current.user.user_id, user.user_id, "staff.created", ["full_name", "email"])
        await self._commit()
        return self.item(user)

    async def update_staff(
        self, current: AuthenticatedAdmin, user_id: uuid.UUID, payload: StaffUpdate
    ) -> StaffItem:
        await self._actor(current)
        user = await self._target(user_id, payload.expected_updated_at)
        email = normalize_email(payload.email)
        await self._email_available(email, user.user_id)
        changed = [
            key
            for key, value in (
                ("full_name", payload.full_name),
                ("email", email),
                ("is_active", payload.is_active),
            )
            if getattr(user, key) != value
        ]
        if not changed:
            raise ApplicationError(
                "No account changes were provided.", code="staff_unchanged", status_code=409
            )
        user.full_name, user.email, user.is_active = payload.full_name, email, payload.is_active
        user.updated_at = datetime.now(UTC)
        if "email" in changed or "is_active" in changed:
            await self._revoke(user.user_id, user.updated_at)
        self._audit(current.user.user_id, user.user_id, "staff.updated", changed)
        await self._commit()
        return self.item(user)

    async def revoke_sessions(
        self, current: AuthenticatedAdmin, user_id: uuid.UUID, payload: StaffRevoke
    ) -> StaffItem:
        await self._actor(current)
        user = await self._target(user_id, payload.expected_updated_at)
        user.updated_at = datetime.now(UTC)
        await self._revoke(user.user_id, user.updated_at)
        self._audit(current.user.user_id, user.user_id, "staff.sessions_revoked", [])
        await self._commit()
        return self.item(user)

    async def _revoke(self, user_id: uuid.UUID, now: datetime) -> None:
        await self.database.execute(
            update(AuthSession)
            .where(AuthSession.user_id == user_id, AuthSession.revoked_at.is_(None))
            .values(revoked_at=now)
        )

    def _audit(self, actor: uuid.UUID, target: uuid.UUID, action: str, fields: list[str]) -> None:
        self.database.add(
            AuditLog(
                actor_user_id=actor,
                action=action,
                entity_type="user",
                entity_id=target,
                details=json.dumps({"changed_fields": fields}),
            )
        )

    async def _commit(self) -> None:
        try:
            await self.database.flush()
            await self.database.commit()
        except IntegrityError as error:
            await self.database.rollback()
            raise ApplicationError(
                "Account details conflict with an existing record.",
                code="staff_write_conflict",
                status_code=409,
            ) from error

    @staticmethod
    def _utc(value: datetime) -> datetime:
        return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)

    @staticmethod
    def item(user: User) -> StaffItem:
        return StaffItem(
            user_id=user.user_id,
            full_name=user.full_name,
            email=user.email,
            role=cast(Literal["admin", "operations_admin"], user.role),
            is_active=user.is_active,
            created_at=user.created_at,
            updated_at=user.updated_at,
        )
