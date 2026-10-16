import uuid
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Query, Request, Response, status

from app.api.dependencies import (
    AdminResponseUnitServiceDependency,
    CurrentAdmin,
    SettingsDependency,
    require_trusted_origin,
)
from app.core.exceptions import ApplicationError
from app.models.enums import ADMINISTRATOR_ROLES
from app.schemas.admin_response_units import (
    AdminResponseUnitCreateRequest,
    AdminResponseUnitListItem,
    AdminResponseUnitListResponse,
    AdminResponseUnitUpdateRequest,
)
from app.services.admin_auth import AuthenticatedAdmin
from app.services.admin_response_units import AdminResponseUnitFilters

router = APIRouter(prefix="/response-units")
ResponseUnitStatusQuery = Literal["available", "assigned", "responding", "offline"]


def _prevent_response_caching(response: Response) -> None:
    response.headers["Cache-Control"] = "no-store, max-age=0"
    response.headers["Pragma"] = "no-cache"


def _require_response_unit_admin(current: AuthenticatedAdmin) -> None:
    if current.user.role not in ADMINISTRATOR_ROLES:
        raise ApplicationError(
            "This staff account cannot manage the response-unit roster.",
            code="response_unit_management_forbidden",
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
    response_model=AdminResponseUnitListResponse,
    status_code=status.HTTP_200_OK,
    summary="List response units for the staff dashboard",
)
async def list_response_units(
    response: Response,
    current: CurrentAdmin,
    service: AdminResponseUnitServiceDependency,
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 20,
    search: Annotated[str | None, Query(min_length=1, max_length=100)] = None,
    unit_status: Annotated[list[ResponseUnitStatusQuery] | None, Query()] = None,
) -> AdminResponseUnitListResponse:
    del current
    _prevent_response_caching(response)
    return await service.list_units(
        AdminResponseUnitFilters(
            page=page,
            page_size=page_size,
            search=search,
            statuses=tuple(unit_status or ()),
        )
    )


@router.post(
    "",
    response_model=AdminResponseUnitListItem,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(require_trusted_origin)],
    summary="Register a response unit",
)
async def create_response_unit(
    payload: AdminResponseUnitCreateRequest,
    request: Request,
    response: Response,
    current: CurrentAdmin,
    service: AdminResponseUnitServiceDependency,
    settings: SettingsDependency,
) -> AdminResponseUnitListItem:
    _prevent_response_caching(response)
    _require_response_unit_admin(current)
    return await service.create_unit(
        staff_id=current.user.user_id,
        payload=payload,
        ip_address=_client_ip(
            request,
            trust_proxy_headers=bool(settings.trust_proxy_headers),
        ),
    )


@router.patch(
    "/{unit_id}",
    response_model=AdminResponseUnitListItem,
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(require_trusted_origin)],
    summary="Edit response-unit roster details",
)
async def update_response_unit(
    unit_id: uuid.UUID,
    payload: AdminResponseUnitUpdateRequest,
    request: Request,
    response: Response,
    current: CurrentAdmin,
    service: AdminResponseUnitServiceDependency,
    settings: SettingsDependency,
) -> AdminResponseUnitListItem:
    _prevent_response_caching(response)
    _require_response_unit_admin(current)
    return await service.update_unit(
        unit_id,
        staff_id=current.user.user_id,
        payload=payload,
        ip_address=_client_ip(
            request,
            trust_proxy_headers=bool(settings.trust_proxy_headers),
        ),
    )
