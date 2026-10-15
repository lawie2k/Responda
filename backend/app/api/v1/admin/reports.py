import uuid
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Query, Request, Response, status

from app.api.dependencies import (
    AdminReportServiceDependency,
    CurrentAdmin,
    SettingsDependency,
    require_trusted_origin,
)
from app.core.exceptions import ApplicationError
from app.schemas.admin_reports import (
    AdminReportDetailResponse,
    AdminReportListResponse,
    AdminReportReviewRequest,
    AdminReportReviewResult,
)
from app.services.admin_auth import AuthenticatedAdmin
from app.services.admin_reports import AdminReportFilters

router = APIRouter(prefix="/reports")

PriorityQuery = Literal["critical", "high", "medium", "low"]
ReportStatusQuery = Literal["new", "under_review", "linked", "closed"]
VerificationStatusQuery = Literal["pending", "verified", "unverified", "invalid"]
ReportSourceQuery = Literal["app_api", "app_sms", "manual"]
IncidentStatusQuery = Literal["open", "dispatched", "responding", "resolved", "closed"]
REPORT_REVIEWER_ROLES = {"admin", "verifier"}


def _prevent_response_caching(response: Response) -> None:
    response.headers["Cache-Control"] = "no-store, max-age=0"
    response.headers["Pragma"] = "no-cache"


def _require_report_reviewer(current: AuthenticatedAdmin) -> None:
    if current.user.role not in REPORT_REVIEWER_ROLES:
        raise ApplicationError(
            "This staff account cannot review reports.",
            code="report_review_forbidden",
            status_code=403,
        )


def _client_ip(request: Request, *, trust_proxy_headers: bool) -> str:
    if trust_proxy_headers:
        forwarded_for = request.headers.get("x-forwarded-for")
        if forwarded_for:
            return forwarded_for.split(",", maxsplit=1)[0].strip()[:45]
    return request.client.host[:45] if request.client is not None else "unknown"


@router.get(
    "",
    response_model=AdminReportListResponse,
    status_code=status.HTTP_200_OK,
    summary="List reports for the staff dashboard",
)
async def list_reports(
    response: Response,
    current: CurrentAdmin,
    service: AdminReportServiceDependency,
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 20,
    search: Annotated[str | None, Query(min_length=1, max_length=100)] = None,
    report_status: Annotated[list[ReportStatusQuery] | None, Query()] = None,
    verification_status: Annotated[list[VerificationStatusQuery] | None, Query()] = None,
    priority: Annotated[list[PriorityQuery] | None, Query()] = None,
    source: Annotated[list[ReportSourceQuery] | None, Query()] = None,
    incident_status: Annotated[list[IncidentStatusQuery] | None, Query()] = None,
    incident_type_id: uuid.UUID | None = None,
    sort: Literal["newest", "oldest"] = "newest",
) -> AdminReportListResponse:
    del current
    _prevent_response_caching(response)
    return await service.list_reports(
        AdminReportFilters(
            page=page,
            page_size=page_size,
            search=search,
            statuses=tuple(report_status or ()),
            verification_statuses=tuple(verification_status or ()),
            priorities=tuple(priority or ()),
            sources=tuple(source or ()),
            incident_statuses=tuple(incident_status or ()),
            incident_type_id=incident_type_id,
            sort=sort,
        )
    )


@router.get(
    "/{report_id}",
    response_model=AdminReportDetailResponse,
    status_code=status.HTTP_200_OK,
    summary="Get one report for staff review",
)
async def get_report(
    report_id: uuid.UUID,
    response: Response,
    current: CurrentAdmin,
    service: AdminReportServiceDependency,
) -> AdminReportDetailResponse:
    del current
    _prevent_response_caching(response)
    return await service.get_report(report_id)


@router.post(
    "/{report_id}/reviews",
    response_model=AdminReportReviewResult,
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(require_trusted_origin)],
    summary="Review a pending report",
)
async def review_report(
    report_id: uuid.UUID,
    payload: AdminReportReviewRequest,
    request: Request,
    response: Response,
    current: CurrentAdmin,
    service: AdminReportServiceDependency,
    settings: SettingsDependency,
) -> AdminReportReviewResult:
    _prevent_response_caching(response)
    _require_report_reviewer(current)
    return await service.review_report(
        report_id,
        reviewer_id=current.user.user_id,
        payload=payload,
        ip_address=_client_ip(
            request,
            trust_proxy_headers=bool(settings.trust_proxy_headers),
        ),
    )
