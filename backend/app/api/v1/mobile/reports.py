import uuid
from typing import Annotated, Literal

from fastapi import APIRouter, Query, Request, status

from app.api.dependencies import DatabaseSession, MobileReportServiceDependency, SettingsDependency
from app.api.v1.mobile.auth import CurrentMobileUser, PrivateRoute
from app.core.exceptions import ApplicationError
from app.core.rate_limit import LoginRateLimiter
from app.schemas.mobile_reports import (
    MobileReportCreateRequest,
    MobileReportCreateResponse,
    MobileReportListResponse,
    MobileReportTrackingResponse,
)

router = APIRouter(prefix="/reports", route_class=PrivateRoute)


@router.get("", response_model=MobileReportListResponse)
async def list_reports(
    reporter: CurrentMobileUser,
    service: MobileReportServiceDependency,
    category: Literal["active", "completed"] = "active",
    page: Annotated[int, Query(ge=1, le=100000)] = 1,
    page_size: Annotated[int, Query(ge=1, le=50)] = 20,
) -> MobileReportListResponse:
    return await service.list_reports(
        reporter_id=reporter.user_id,
        category=category,
        page=page,
        page_size=page_size,
    )


@router.get("/{report_id}", response_model=MobileReportTrackingResponse)
async def report_tracking(
    report_id: uuid.UUID,
    reporter: CurrentMobileUser,
    service: MobileReportServiceDependency,
) -> MobileReportTrackingResponse:
    return await service.get_report(reporter_id=reporter.user_id, report_id=report_id)


@router.post(
    "",
    response_model=MobileReportCreateResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Submit a report from an authenticated mobile account",
)
async def create_report(
    payload: MobileReportCreateRequest,
    request: Request,
    reporter: CurrentMobileUser,
    service: MobileReportServiceDependency,
    settings: SettingsDependency,
) -> MobileReportCreateResponse:
    limiter: LoginRateLimiter = request.app.state.mobile_report_limiter
    forwarded_ip = request.headers.get("x-forwarded-for") if settings.trust_proxy_headers else None
    ip_address = (
        forwarded_ip.split(",", maxsplit=1)[0].strip()[:45]
        if forwarded_ip
        else request.client.host[:45]
        if request.client is not None
        else "unknown"
    )
    retry_after = await limiter.consume(
        ip_address=ip_address,
        identity=str(reporter.user_id),
    )
    if retry_after is not None:
        raise ApplicationError(
            "Too many reports were submitted. Try again later.",
            code="report_rate_limited",
            status_code=429,
            headers={"Retry-After": str(retry_after)},
        )
    return await service.create_report(reporter=reporter, payload=payload)


@router.post("/{report_id}/photo", status_code=201)
async def upload_photo(
    report_id: uuid.UUID,
    request: Request,
    reporter: CurrentMobileUser,
    settings: SettingsDependency,
    db: DatabaseSession,
) -> dict[str, str]:
    from app.services.report_photos import MAX_PHOTO_BYTES, save_photo

    if request.headers.get("content-type", "").split(";")[0] not in {"image/jpeg", "image/png"}:
        raise ApplicationError("Use JPEG or PNG.", code="invalid_photo", status_code=415)
    limiter: LoginRateLimiter = request.app.state.mobile_report_limiter
    retry = await limiter.consume(
        ip_address=request.client.host if request.client else "unknown",
        identity=f"photo:{reporter.user_id}",
    )
    if retry is not None:
        raise ApplicationError(
            "Too many photo uploads. Retry later.",
            code="photo_rate_limited",
            status_code=429,
            headers={"Retry-After": str(retry)},
        )
    chunks = bytearray()
    async for chunk in request.stream():
        chunks.extend(chunk)
        if len(chunks) > MAX_PHOTO_BYTES:
            raise ApplicationError(
                "Photos must be at most 5 MB.", code="photo_too_large", status_code=413
            )
    return await save_photo(db, settings, report_id, reporter.user_id, bytes(chunks))
