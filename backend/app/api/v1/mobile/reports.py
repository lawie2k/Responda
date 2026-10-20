from fastapi import APIRouter, Request, status

from app.api.dependencies import MobileReportServiceDependency, SettingsDependency
from app.api.v1.mobile.auth import CurrentMobileUser, PrivateRoute
from app.core.exceptions import ApplicationError
from app.core.rate_limit import LoginRateLimiter
from app.schemas.mobile_reports import MobileReportCreateRequest, MobileReportCreateResponse

router = APIRouter(prefix="/reports", route_class=PrivateRoute)


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
