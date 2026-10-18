import json
import uuid
from contextlib import suppress
from datetime import UTC, datetime
from math import ceil
from typing import cast

from sqlalchemy import case, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.sql.elements import ColumnElement

from app.core.exceptions import ApplicationError
from app.models import AuditLog, AuthSession, Report, User
from app.models.enums import ADMINISTRATOR_ROLES
from app.schemas.admin_mobile_accounts import (
    MobileAccountCounts,
    MobileAccountItem,
    MobileAccountList,
    MobileAccountStatusUpdate,
)
from app.services.admin_auth import AuthenticatedAdmin


class AdminMobileAccountService:
    def __init__(self, database: AsyncSession) -> None:
        self.db = database

    @staticmethod
    def conditions() -> list[ColumnElement[bool]]:
        # Manual intake callers are not registered mobile accounts.
        return [
            User.role == "reporter",
            User.deleted_at.is_(None),
            User.phone_number.is_not(None),
            User.phone_verified_at.is_not(None),
            User.privacy_notice_accepted_at.is_not(None),
        ]

    @staticmethod
    def require_reader(current: AuthenticatedAdmin) -> None:
        if current.user.role not in ADMINISTRATOR_ROLES:
            raise ApplicationError(
                "Administrator access required.", code="account_access_forbidden", status_code=403
            )

    async def list_accounts(
        self,
        current: AuthenticatedAdmin,
        *,
        page: int,
        page_size: int,
        search: str | None,
        active: bool | None,
    ) -> MobileAccountList:
        self.require_reader(current)
        conditions = self.conditions()
        if search and search.strip():
            value = search.strip()
            escaped = value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
            matches: list[ColumnElement[bool]] = [
                User.full_name.ilike(f"%{escaped}%", escape="\\"),
                User.barangay.ilike(f"%{escaped}%", escape="\\"),
            ]
            with suppress(ValueError):
                matches.append(User.user_id == uuid.UUID(value))
            # Permit exact phone lookup without disclosing full contacts in results.
            digits = value.replace(" ", "").replace("-", "")
            if digits.startswith("09") and len(digits) == 11:
                digits = "+63" + digits[1:]
            if digits.startswith("+639") and len(digits) == 13 and digits[1:].isdigit():
                matches.append(User.phone_number == digits)
            conditions.append(or_(*matches))
        if active is not None:
            conditions.append(User.is_active == active)
        total = int(
            await self.db.scalar(select(func.count()).select_from(User).where(*conditions)) or 0
        )
        count_row = (
            await self.db.execute(
                select(
                    func.count(),
                    func.coalesce(func.sum(case((User.is_active.is_(True), 1), else_=0)), 0),
                )
                .select_from(User)
                .where(*self.conditions())
            )
        ).one()
        counts = MobileAccountCounts(
            total=count_row[0], active=int(count_row[1]), suspended=count_row[0] - int(count_row[1])
        )
        users = (
            await self.db.scalars(
                select(User)
                .where(*conditions)
                .order_by(User.created_at.desc(), User.user_id.desc())
                .offset((page - 1) * page_size)
                .limit(page_size)
            )
        ).all()
        items = await self._items(list(users))
        return MobileAccountList(
            items=items,
            total=total,
            page=page,
            page_size=page_size,
            total_pages=ceil(total / page_size),
            counts=counts,
        )

    async def _items(self, users: list[User]) -> list[MobileAccountItem]:
        if not users:
            return []
        ids = [user.user_id for user in users]
        logins = dict(
            (
                await self.db.execute(
                    select(
                        AuthSession.user_id,
                        func.max(AuthSession.created_at),
                    )
                    .where(AuthSession.user_id.in_(ids))
                    .group_by(AuthSession.user_id)
                )
            ).all()
        )
        reports = dict(
            (
                await self.db.execute(
                    select(Report.reporter_id, func.count())
                    .where(
                        Report.reporter_id.in_(ids),
                        Report.deleted_at.is_(None),
                        Report.source.in_(["app_api", "app_sms"]),
                    )
                    .group_by(Report.reporter_id)
                )
            ).all()
        )
        return [
            MobileAccountItem(
                user_id=user.user_id,
                full_name=user.full_name,
                masked_phone="+63 ••• ••• " + (user.phone_number or "")[-4:],
                barangay=user.barangay,
                is_active=user.is_active,
                created_at=user.created_at,
                updated_at=user.updated_at,
                phone_verified_at=cast(datetime, user.phone_verified_at),
                privacy_notice_accepted_at=cast(datetime, user.privacy_notice_accepted_at),
                last_sign_in_at=logins.get(user.user_id),
                reports_submitted=reports.get(user.user_id, 0),
            )
            for user in users
        ]

    async def update_status(
        self, current: AuthenticatedAdmin, user_id: uuid.UUID, payload: MobileAccountStatusUpdate
    ) -> MobileAccountItem:
        actor = await self.db.scalar(
            select(User)
            .where(User.user_id == current.user.user_id)
            .with_for_update()
            .execution_options(populate_existing=True)
        )
        session = await self.db.scalar(
            select(AuthSession)
            .where(
                AuthSession.session_id == current.session.session_id,
                AuthSession.user_id == current.user.user_id,
            )
            .execution_options(populate_existing=True)
        )
        now = datetime.now(UTC)
        if (
            actor is None
            or actor.role != "admin"
            or not actor.is_active
            or actor.deleted_at is not None
            or session is None
            or session.revoked_at is not None
            or self._utc(session.expires_at) <= now
        ):
            raise ApplicationError(
                "A valid Super Admin session is required.",
                code="account_management_forbidden",
                status_code=403,
            )
        user = await self.db.scalar(
            select(User)
            .where(User.user_id == user_id, *self.conditions())
            .with_for_update()
            .execution_options(populate_existing=True)
        )
        if user is None:
            raise ApplicationError(
                "Mobile account not found.", code="mobile_account_not_found", status_code=404
            )
        if self._utc(user.updated_at) != self._utc(payload.expected_updated_at):
            raise ApplicationError(
                "This account changed. Refresh before saving.",
                code="account_update_conflict",
                status_code=409,
            )
        if user.is_active == payload.is_active:
            raise ApplicationError(
                "This account already has that status.", code="account_unchanged", status_code=409
            )
        if payload.is_active != (payload.reason == "review_completed"):
            raise ApplicationError(
                "Choose a reason appropriate for this status change.",
                code="invalid_status_reason",
                status_code=422,
            )
        user.is_active = payload.is_active
        user.updated_at = now
        await self.db.execute(
            update(AuthSession)
            .where(
                AuthSession.user_id == user.user_id,
                AuthSession.revoked_at.is_(None),
            )
            .values(revoked_at=now)
        )
        self.db.add(
            AuditLog(
                actor_user_id=actor.user_id,
                entity_type="user",
                entity_id=user.user_id,
                action="mobile.account.restored"
                if payload.is_active
                else "mobile.account.suspended",
                details=json.dumps({"reason": payload.reason}),
            )
        )
        await self.db.flush()
        item = (await self._items([user]))[0]
        await self.db.commit()
        return item

    @staticmethod
    def _utc(value: datetime) -> datetime:
        return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)
