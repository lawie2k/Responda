import uuid
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Query, Request, Response, status

from app.api.dependencies import (
    AdminIncidentServiceDependency,
    CurrentAdmin,
    SettingsDependency,
    require_trusted_origin,
)
from app.core.exceptions import ApplicationError
from app.models.enums import ADMINISTRATOR_ROLES
from app.schemas.admin_incidents import (
    AdminIncidentCreateRequest,
    AdminIncidentLinkResult,
    AdminIncidentListResponse,
    AdminIncidentReportLinkRequest,
)
from app.services.admin_auth import AuthenticatedAdmin
from app.services.admin_incidents import AdminIncidentFilters

router = APIRouter(prefix="/incidents")
IncidentStatusQuery = Literal["open", "dispatched", "responding", "resolved", "closed"]


def _prevent_response_caching(response: Response) -> None:
    response.headers["Cache-Control"] = "no-store, max-age=0"
    response.headers["Pragma"] = "no-cache"


def _require_incident_operator(current: AuthenticatedAdmin) -> None:
    if current.user.role not in ADMINISTRATOR_ROLES:
        raise ApplicationError(
            "This staff account cannot manage incidents.",
            code="incident_operation_forbidden",
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
    response_model=AdminIncidentListResponse,
    status_code=status.HTTP_200_OK,
    summary="List incidents for the staff dashboard",
)
async def list_incidents(
    response: Response,
    current: CurrentAdmin,
    service: AdminIncidentServiceDependency,
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 20,
    search: Annotated[str | None, Query(min_length=1, max_length=100)] = None,
    incident_status: Annotated[list[IncidentStatusQuery] | None, Query()] = None,
    incident_type_id: uuid.UUID | None = None,
) -> AdminIncidentListResponse:
    del current
    _prevent_response_caching(response)
    return await service.list_incidents(
        AdminIncidentFilters(
            page=page,
            page_size=page_size,
            search=search,
            statuses=tuple(incident_status or ()),
            incident_type_id=incident_type_id,
        )
    )


@router.post(
    "",
    response_model=AdminIncidentLinkResult,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(require_trusted_origin)],
    summary="Create an incident from a verified report",
)
async def create_incident(
    payload: AdminIncidentCreateRequest,
    request: Request,
    response: Response,
    current: CurrentAdmin,
    service: AdminIncidentServiceDependency,
    settings: SettingsDependency,
) -> AdminIncidentLinkResult:
    _prevent_response_caching(response)
    _require_incident_operator(current)
    return await service.create_from_report(
        staff_id=current.user.user_id,
        payload=payload,
        ip_address=_client_ip(
            request,
            trust_proxy_headers=bool(settings.trust_proxy_headers),
        ),
    )


@router.post(
    "/{incident_id}/reports",
    response_model=AdminIncidentLinkResult,
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(require_trusted_origin)],
    summary="Link a verified report to an active incident",
)
async def link_report_to_incident(
    incident_id: uuid.UUID,
    payload: AdminIncidentReportLinkRequest,
    request: Request,
    response: Response,
    current: CurrentAdmin,
    service: AdminIncidentServiceDependency,
    settings: SettingsDependency,
) -> AdminIncidentLinkResult:
    _prevent_response_caching(response)
    _require_incident_operator(current)
    return await service.link_report(
        incident_id,
        staff_id=current.user.user_id,
        payload=payload,
        ip_address=_client_ip(
            request,
            trust_proxy_headers=bool(settings.trust_proxy_headers),
        ),
    )
