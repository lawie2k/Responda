import json
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.concurrency import run_in_threadpool

from app.core.config import Settings
from app.core.exceptions import ApplicationError
from app.core.security import (
    generate_session_token,
    hash_password,
    hash_session_token,
    normalize_email,
    password_needs_rehash,
    verify_password,
)
from app.models import AuditLog, AuthSession, User
from app.models.enums import ADMINISTRATOR_ROLES


@dataclass(frozen=True, slots=True)
class AdminLoginResult:
    user: User
    session: AuthSession
    token: str


@dataclass(frozen=True, slots=True)
class AuthenticatedAdmin:
    user: User
    session: AuthSession


class AdminAuthService:
    def __init__(self, database: AsyncSession, settings: Settings) -> None:
        self._database = database
        self._settings = settings

    async def login(
        self,
        *,
        email: str,
        password: str,
        ip_address: str,
        device_name: str | None,
    ) -> AdminLoginResult:
        normalized_email = normalize_email(email)
        user = await self._find_user_by_email(normalized_email)
        password_hash = user.password_hash if user is not None else None
        password_is_valid = await run_in_threadpool(verify_password, password, password_hash)

        if user is None or not password_is_valid:
            await self._record_audit(
                action="auth.login.failed",
                actor_user_id=user.user_id if user is not None else None,
                entity_id=user.user_id if user is not None else None,
                result="invalid_credentials",
                ip_address=ip_address,
            )
            raise ApplicationError(
                "Invalid email or password.",
                code="invalid_credentials",
                status_code=401,
            )

        if not user.is_active:
            await self._record_audit(
                action="auth.login.rejected",
                actor_user_id=user.user_id,
                entity_id=user.user_id,
                result="inactive_account",
                ip_address=ip_address,
            )
            raise ApplicationError(
                "This account is inactive.",
                code="account_inactive",
                status_code=403,
            )

        if user.role not in ADMINISTRATOR_ROLES:
            await self._record_audit(
                action="auth.login.rejected",
                actor_user_id=user.user_id,
                entity_id=user.user_id,
                result="staff_access_required",
                ip_address=ip_address,
            )
            raise ApplicationError(
                "This account cannot access the staff dashboard.",
                code="staff_access_required",
                status_code=403,
            )

        if user.password_hash is not None and password_needs_rehash(user.password_hash):
            user.password_hash = await run_in_threadpool(hash_password, password)

        token = generate_session_token()
        now = datetime.now(UTC)
        auth_session = AuthSession(
            user_id=user.user_id,
            refresh_token_hash=hash_session_token(token),
            device_name=device_name,
            expires_at=now + timedelta(seconds=self._settings.admin_session_ttl_seconds),
        )
        await self._revoke_excess_sessions(user.user_id, now)
        self._database.add(auth_session)
        self._database.add(
            AuditLog(
                actor_user_id=user.user_id,
                action="auth.login.succeeded",
                entity_type="user",
                entity_id=user.user_id,
                details=json.dumps({"result": "success"}),
                ip_address=ip_address,
            )
        )
        await self._database.commit()
        await self._database.refresh(auth_session)
        return AdminLoginResult(user=user, session=auth_session, token=token)

    async def authenticate(self, token: str | None) -> AuthenticatedAdmin:
        if not token:
            raise self._invalid_session_error()

        statement = (
            select(AuthSession, User)
            .join(User, User.user_id == AuthSession.user_id)
            .where(
                AuthSession.refresh_token_hash == hash_session_token(token),
                User.deleted_at.is_(None),
            )
        )
        result = await self._database.execute(statement)
        row = result.one_or_none()
        if row is None:
            raise self._invalid_session_error()

        auth_session, user = row
        now = datetime.now(UTC)
        if auth_session.revoked_at is not None or auth_session.expires_at <= now:
            raise self._invalid_session_error()
        if not user.is_active or user.role not in ADMINISTRATOR_ROLES:
            raise self._invalid_session_error()
        return AuthenticatedAdmin(user=user, session=auth_session)

    async def logout(self, context: AuthenticatedAdmin, *, ip_address: str) -> None:
        if context.session.revoked_at is None:
            context.session.revoked_at = datetime.now(UTC)
            self._database.add(
                AuditLog(
                    actor_user_id=context.user.user_id,
                    action="auth.logout",
                    entity_type="auth_session",
                    entity_id=context.session.session_id,
                    details=json.dumps({"result": "success"}),
                    ip_address=ip_address,
                )
            )
            await self._database.commit()

    async def _find_user_by_email(self, email: str) -> User | None:
        statement = (
            select(User)
            .where(
                func.lower(User.email) == email,
                User.deleted_at.is_(None),
            )
            .with_for_update()
            .execution_options(populate_existing=True)
        )
        result = await self._database.execute(statement)
        return result.scalar_one_or_none()

    async def _revoke_excess_sessions(self, user_id: uuid.UUID, now: datetime) -> None:
        statement = (
            select(AuthSession)
            .where(
                AuthSession.user_id == user_id,
                AuthSession.revoked_at.is_(None),
                AuthSession.expires_at > now,
            )
            .order_by(AuthSession.created_at.asc())
            .with_for_update()
        )
        result = await self._database.execute(statement)
        active_sessions = list(result.scalars())
        number_to_revoke = max(
            0,
            len(active_sessions) - self._settings.admin_max_sessions_per_user + 1,
        )
        for session in active_sessions[:number_to_revoke]:
            session.revoked_at = now

    async def _record_audit(
        self,
        *,
        action: str,
        actor_user_id: uuid.UUID | None,
        entity_id: uuid.UUID | None,
        result: str,
        ip_address: str,
    ) -> None:
        self._database.add(
            AuditLog(
                actor_user_id=actor_user_id,
                action=action,
                entity_type="user",
                entity_id=entity_id,
                details=json.dumps({"result": result}),
                ip_address=ip_address,
            )
        )
        await self._database.commit()

    @staticmethod
    def _invalid_session_error() -> ApplicationError:
        return ApplicationError(
            "A valid staff session is required.",
            code="invalid_session",
            status_code=401,
        )
