"""Send encrypted, minimal new-report alerts to opted-in, active staff sessions."""

import asyncio
import base64
import json
import uuid
from datetime import UTC, datetime, timedelta
from pathlib import Path
from urllib.parse import urlparse

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from pywebpush import WebPushException, webpush  # type: ignore[import-untyped]
from sqlalchemy import and_, or_, select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker
from starlette.concurrency import run_in_threadpool

from app.core.config import Settings
from app.models import AuthSession, Report, User
from app.models.entities import WebPushSubscription


def valid_endpoint(value: str) -> bool:
    url = urlparse(value)
    return (
        url.scheme == "https"
        and url.hostname
        in {"fcm.googleapis.com", "updates.push.services.mozilla.com", "web.push.apple.com"}
        and url.port in {None, 443}
        and not url.username
        and not url.password
        and not url.fragment
    )


def public_key(settings: Settings) -> str:
    key = serialization.load_pem_private_key(
        Path(settings.web_push_key_file).read_bytes(), password=None
    )
    if not isinstance(key, ec.EllipticCurvePrivateKey):
        raise ValueError("Expected EC private key")
    raw = key.public_key().public_bytes(
        serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint
    )
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def deliver(subscription: WebPushSubscription, report_id: uuid.UUID, settings: Settings) -> bool:
    if not valid_endpoint(subscription.endpoint):
        return False
    try:
        webpush(
            subscription_info={
                "endpoint": subscription.endpoint,
                "keys": {"p256dh": subscription.p256dh, "auth": subscription.auth},
            },
            data=json.dumps(
                {
                    "title": "New Responda report",
                    "body": "An emergency report needs staff review.",
                    "reportId": str(report_id),
                }
            ),
            vapid_private_key=settings.web_push_key_file,
            vapid_claims={"sub": settings.web_push_subject},
            timeout=10,
            ttl=300,
        )
    except WebPushException as error:
        if error.response is not None and error.response.status_code in {404, 410}:
            return False
        raise
    return True


async def send_pending(db: AsyncSession, settings: Settings) -> None:
    now = datetime.now(UTC)
    subscription = await db.scalar(
        select(WebPushSubscription)
        .join(AuthSession, AuthSession.session_id == WebPushSubscription.session_id)
        .join(User, User.user_id == WebPushSubscription.user_id)
        .where(
            User.is_active.is_(True),
            User.deleted_at.is_(None),
            User.role.in_(["admin", "operations_admin"]),
            AuthSession.revoked_at.is_(None),
            AuthSession.expires_at > now,
            WebPushSubscription.next_attempt_at <= now,
        )
        .order_by(WebPushSubscription.next_attempt_at)
        .limit(1)
        .with_for_update(of=WebPushSubscription, skip_locked=True)
    )
    if subscription is None:
        return
    rows = (
        await db.execute(
            select(Report.report_id, Report.received_at)
            .where(
                Report.deleted_at.is_(None),
                Report.received_at >= now - timedelta(days=7),
                or_(
                    Report.received_at > subscription.cursor_at,
                    and_(
                        Report.received_at == subscription.cursor_at,
                        Report.report_id > subscription.cursor_id,
                    ),
                ),
            )
            .order_by(Report.received_at, Report.report_id)
            .limit(10)
        )
    ).all()
    subscription.next_attempt_at = now + timedelta(seconds=5)
    for report_id, received_at in rows:
        try:
            alive = await run_in_threadpool(deliver, subscription, report_id, settings)
        except Exception:
            # Third-party errors may contain endpoint capabilities: never log their text.
            subscription.next_attempt_at = now + timedelta(seconds=60)
            break
        if not alive:
            await db.delete(subscription)
            break
        subscription.cursor_at = received_at
        subscription.cursor_id = report_id
    await db.commit()


async def push_worker(factory: async_sessionmaker[AsyncSession], settings: Settings) -> None:
    while True:
        try:
            async with factory() as db:
                await send_pending(db, settings)
        except (SQLAlchemyError, OSError):
            # A transient outage retries; it must not terminate report intake or expose SQL values.
            pass
        await asyncio.sleep(1)
