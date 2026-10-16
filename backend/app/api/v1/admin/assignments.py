import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Query, Request, Response, status

from app.api.dependencies import (
    AdminAssignmentServiceDependency,
    CurrentAdmin,
    SettingsDependency,
    require_trusted_origin,
)
from app.core.exceptions import ApplicationError
from app.models.enums import ADMINISTRATOR_ROLES
from app.schemas.admin_assignments import (
    AdminAssignmentCreateRequest,
    AdminAssignmentListResponse,
    AdminAssignmentMutationResult,
    AdminAssignmentTransitionRequest,
)
from app.services.admin_auth import AuthenticatedAdmin

router = APIRouter()


def _prevent_response_caching(response: Response) -> None:
    response.headers["Cache-Control"] = "no-store, max-age=0"
    response.headers["Pragma"] = "no-cache"


def _require_assignment_admin(current: AuthenticatedAdmin) -> None:
    if current.user.role not in ADMINISTRATOR_ROLES:
        raise ApplicationError(
            "This staff account cannot manage response assignments.",
            code="assignment_management_forbidden",
            status_code=403,
        )


def _client_ip(request: Request, *, trust_proxy_headers: bool) -> str:
    if trust_proxy_headers:
        forwarded_for = request.headers.get("x-forwarded-for")
        if forwarded_for:
            return forwarded_for.split(",", maxsplit=1)[0].strip()[:45]
    return request.client.host[:45] if request.client is not None else "unknown"


@router.get(
    "/incidents/{incident_id}/assignments",
    response_model=AdminAssignmentListResponse,
    status_code=status.HTTP_200_OK,
    summary="List response assignments for an incident",
)
async def list_incident_assignments(
    incident_id: uuid.UUID,
    response: Response,
    current: CurrentAdmin,
    service: AdminAssignmentServiceDependency,
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 20,
) -> AdminAssignmentListResponse:
    _require_assignment_admin(current)
    _prevent_response_caching(response)
    return await service.list_assignments(
        incident_id,
        page=page,
        page_size=page_size,
    )


@router.post(
    "/incidents/{incident_id}/assignments",
    response_model=AdminAssignmentMutationResult,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(require_trusted_origin)],
    summary="Assign an available response unit to an incident",
)
async def create_incident_assignment(
    incident_id: uuid.UUID,
    payload: AdminAssignmentCreateRequest,
    request: Request,
    response: Response,
    current: CurrentAdmin,
    service: AdminAssignmentServiceDependency,
    settings: SettingsDependency,
) -> AdminAssignmentMutationResult:
    _require_assignment_admin(current)
    _prevent_response_caching(response)
    return await service.create_assignment(
        incident_id,
        staff_id=current.user.user_id,
        payload=payload,
        ip_address=_client_ip(
            request,
            trust_proxy_headers=bool(settings.trust_proxy_headers),
        ),
    )


@router.post(
    "/assignments/{assignment_id}/transitions",
    response_model=AdminAssignmentMutationResult,
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(require_trusted_origin)],
    summary="Move a response assignment to its next lifecycle status",
)
async def transition_assignment(
    assignment_id: uuid.UUID,
    payload: AdminAssignmentTransitionRequest,
    request: Request,
    response: Response,
    current: CurrentAdmin,
    service: AdminAssignmentServiceDependency,
    settings: SettingsDependency,
) -> AdminAssignmentMutationResult:
    _require_assignment_admin(current)
    _prevent_response_caching(response)
    return await service.transition_assignment(
        assignment_id,
        staff_id=current.user.user_id,
        payload=payload,
        ip_address=_client_ip(
            request,
            trust_proxy_headers=bool(settings.trust_proxy_headers),
        ),
    )
