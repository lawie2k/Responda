import base64
import uuid
from datetime import UTC, datetime

from cryptography.hazmat.primitives.asymmetric import ec
from fastapi import APIRouter, Depends
from pydantic import BaseModel, ConfigDict, Field, ValidationInfo, field_validator
from sqlalchemy import func, select

from app.api.dependencies import (
    CurrentAdmin,
    DatabaseSession,
    SettingsDependency,
    require_trusted_origin,
)
from app.api.v1.mobile.auth import PrivateRoute
from app.core.exceptions import ApplicationError
from app.models import User
from app.models.entities import WebPushSubscription
from app.services.web_push import public_key, valid_endpoint

router = APIRouter(prefix="/push", route_class=PrivateRoute)


class SubscriptionRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    endpoint: str = Field(max_length=2048)
    p256dh: str = Field(max_length=200)
    auth: str = Field(max_length=100)

    @field_validator("endpoint")
    @classmethod
    def endpoint_valid(cls, value: str) -> str:
        try:
            if valid_endpoint(value):
                return value
        except ValueError:
            pass
        raise ValueError("Unsupported push provider")

    @field_validator("p256dh", "auth")
    @classmethod
    def key_valid(cls, value: str, info: ValidationInfo) -> str:
        raw = base64.b64decode(value + "=" * (-len(value) % 4), altchars=b"-_", validate=True)
        if len(raw) != (65 if info.field_name == "p256dh" else 16):
            raise ValueError("Invalid push key")
        if info.field_name == "p256dh":
            ec.EllipticCurvePublicKey.from_encoded_point(ec.SECP256R1(), raw)
        return value


@router.get("/key")
async def get_push_key(current: CurrentAdmin, settings: SettingsDependency) -> dict[str, str]:
    del current
    if not settings.web_push_enabled:
        raise ApplicationError(
            "Browser push is not configured.", code="push_unavailable", status_code=503
        )
    try:
        return {"public_key": public_key(settings)}
    except (OSError, ValueError):
        raise ApplicationError(
            "Browser push key is unavailable.", code="push_unavailable", status_code=503
        ) from None


@router.post("/subscriptions", dependencies=[Depends(require_trusted_origin)])
async def subscribe(
    payload: SubscriptionRequest,
    current: CurrentAdmin,
    db: DatabaseSession,
    settings: SettingsDependency,
) -> dict[str, bool]:
    if not settings.web_push_enabled:
        raise ApplicationError(
            "Browser push is not configured.", code="push_unavailable", status_code=503
        )
    await db.scalar(select(User).where(User.user_id == current.user.user_id).with_for_update())
    existing = await db.scalar(
        select(WebPushSubscription).where(WebPushSubscription.endpoint == payload.endpoint)
    )
    if existing and existing.user_id != current.user.user_id:
        raise ApplicationError(
            "Reset this browser's notification permission before enabling another account.",
            code="push_account_conflict",
            status_code=409,
        )
    if existing is None:
        count = await db.scalar(
            select(func.count())
            .select_from(WebPushSubscription)
            .where(WebPushSubscription.user_id == current.user.user_id)
        )
        if count and count >= 5:
            raise ApplicationError(
                "Up to five browsers can receive push alerts.", code="push_limit", status_code=409
            )
        existing = WebPushSubscription(
            user_id=current.user.user_id,
            endpoint=payload.endpoint,
            cursor_at=datetime.now(UTC),
            cursor_id=uuid.UUID(int=0),
        )
        db.add(existing)
    existing.session_id = current.session.session_id
    existing.p256dh = payload.p256dh
    existing.auth = payload.auth
    await db.commit()
    return {"ok": True}


@router.post("/unsubscribe", dependencies=[Depends(require_trusted_origin)])
async def unsubscribe(
    payload: SubscriptionRequest, current: CurrentAdmin, db: DatabaseSession
) -> dict[str, bool]:
    existing = await db.scalar(
        select(WebPushSubscription).where(
            WebPushSubscription.user_id == current.user.user_id,
            WebPushSubscription.endpoint == payload.endpoint,
        )
    )
    if existing:
        await db.delete(existing)
        await db.commit()
    return {"ok": True}
