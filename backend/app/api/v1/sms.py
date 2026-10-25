import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Request

from app.api.dependencies import (
    CurrentAdmin,
    DatabaseSession,
    SettingsDependency,
    require_trusted_origin,
)
from app.api.v1.mobile.auth import CurrentMobileUser, PrivateRoute, Token
from app.core.exceptions import ApplicationError
from app.core.rate_limit import LoginRateLimiter
from app.core.security import hash_session_token
from app.schemas.sms import (
    GatewayCreate,
    GatewayCredential,
    GatewaySmsRequest,
    GatewaySmsResult,
    SmsDeviceCredential,
    SmsDeviceInfo,
    SmsDeviceRegistration,
)
from app.services.sms import SmsService

router = APIRouter(route_class=PrivateRoute, tags=["sms"])


def service(db: DatabaseSession, settings: SettingsDependency) -> SmsService:
    return SmsService(db, settings)


Service = Annotated[SmsService, Depends(service)]


async def limit(request: Request, identity: str, kind: str) -> None:
    limiter: LoginRateLimiter = getattr(request.app.state, f"sms_{kind}_limiter")
    # A gateway carries many citizens: per-sender limits must not share its IP bucket.
    ip = identity if kind == "report" else request.client.host if request.client else "unknown"
    retry = await limiter.consume(ip_address=ip, identity=identity)
    if retry is not None:
        raise ApplicationError(
            "Too many SMS requests. Retry later.",
            code="sms_rate_limited",
            status_code=429,
            headers={"Retry-After": str(retry)},
        )


@router.post("/mobile/sms-devices", response_model=SmsDeviceCredential, status_code=201)
async def register_device(
    payload: SmsDeviceRegistration,
    current: CurrentMobileUser,
    sms: Service,
    request: Request,
) -> SmsDeviceCredential:
    await limit(request, str(current.user_id), "register")
    return await sms.register_device(current.user_id, payload.device_id)


@router.get("/mobile/sms-devices", response_model=list[SmsDeviceInfo])
async def list_devices(current: CurrentMobileUser, sms: Service) -> list[SmsDeviceInfo]:
    return await sms.list_devices(current.user_id)


@router.delete("/mobile/sms-devices/{device_id}", status_code=204)
async def revoke_device(device_id: uuid.UUID, current: CurrentMobileUser, sms: Service) -> None:
    await sms.revoke_device(current.user_id, device_id)


@router.post(
    "/admin/sms-gateways",
    response_model=GatewayCredential,
    status_code=201,
    dependencies=[Depends(require_trusted_origin)],
)
async def create_gateway(
    payload: GatewayCreate,
    current: CurrentAdmin,
    sms: Service,
    request: Request,
) -> GatewayCredential:
    await limit(request, str(current.user.user_id), "register")
    return await sms.create_gateway(current, payload)


@router.delete(
    "/admin/sms-gateways/{gateway_id}",
    status_code=204,
    dependencies=[Depends(require_trusted_origin)],
)
async def revoke_gateway(gateway_id: uuid.UUID, current: CurrentAdmin, sms: Service) -> None:
    await sms.revoke_gateway(current, gateway_id)


@router.post(
    "/admin/sms-gateways/{gateway_id}/rotate-token",
    response_model=GatewayCredential,
    dependencies=[Depends(require_trusted_origin)],
)
async def rotate_gateway(
    gateway_id: uuid.UUID, current: CurrentAdmin, sms: Service, request: Request
) -> GatewayCredential:
    await limit(request, str(current.user.user_id), "register")
    return await sms.rotate_gateway(current, gateway_id)


@router.post("/gateway/sms", response_model=GatewaySmsResult)
async def ingest_sms(
    payload: GatewaySmsRequest,
    access: Token,
    sms: Service,
    request: Request,
) -> GatewaySmsResult:
    await limit(request, hash_session_token(access or "anonymous"), "ingest")
    gateway = await sms.authenticate_gateway(access)
    await limit(request, payload.sender_number, "report")
    return await sms.ingest(gateway, payload)
