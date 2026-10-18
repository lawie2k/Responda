import uuid
from collections.abc import Callable, Coroutine
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Query, Request, Response
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.routing import APIRoute

from app.api.dependencies import (
    AdminStaffServiceDependency,
    CurrentAdmin,
    SettingsDependency,
    require_trusted_origin,
)
from app.core.exceptions import ApplicationError
from app.core.security import PASSWORD_MAX_LENGTH, PASSWORD_MIN_LENGTH
from app.schemas.admin_staff import (
    StaffCreate,
    StaffItem,
    StaffList,
    StaffPolicy,
    StaffRevoke,
    StaffUpdate,
)
from app.services.admin_auth import AuthenticatedAdmin


class StaffRoute(APIRoute):
    def get_route_handler(self) -> Callable[[Request], Coroutine[Any, Any, Response]]:
        handler = super().get_route_handler()

        async def safe_handler(request: Request) -> Response:
            try:
                return await handler(request)
            except RequestValidationError:
                # Validation errors must never echo a submitted password or account data.
                return JSONResponse(
                    status_code=422,
                    content={
                        "error": {
                            "code": "invalid_staff_request",
                            "message": "Check account fields, password length, and filters.",
                        }
                    },
                    headers={"Cache-Control": "no-store, max-age=0"},
                )

        return safe_handler


router = APIRouter(prefix="/staff", route_class=StaffRoute)


def prepare(response: Response, current: AuthenticatedAdmin) -> None:
    response.headers["Cache-Control"] = "no-store, max-age=0"
    response.headers["Pragma"] = "no-cache"
    if current.user.role != "admin":
        raise ApplicationError(
            "Only Super Admins can manage staff accounts.",
            code="staff_management_forbidden",
            status_code=403,
        )


@router.get("", response_model=StaffList)
async def list_staff(
    response: Response,
    current: CurrentAdmin,
    service: AdminStaffServiceDependency,
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 10,
    search: Annotated[str | None, Query(min_length=1, max_length=100)] = None,
    active: bool | None = None,
) -> StaffList:
    prepare(response, current)
    return await service.list_staff(page=page, page_size=page_size, search=search, active=active)


@router.get("/policy", response_model=StaffPolicy)
async def get_policy(
    response: Response, current: CurrentAdmin, settings: SettingsDependency
) -> StaffPolicy:
    prepare(response, current)
    return StaffPolicy(
        password_min_length=PASSWORD_MIN_LENGTH,
        password_max_length=PASSWORD_MAX_LENGTH,
        session_ttl_seconds=settings.admin_session_ttl_seconds,
        max_sessions_per_user=settings.admin_max_sessions_per_user,
        login_attempts=settings.admin_login_rate_limit_attempts,
        login_window_seconds=settings.admin_login_rate_limit_window_seconds,
        secure_cookies=settings.admin_session_cookie_secure,
    )


@router.post(
    "", response_model=StaffItem, status_code=201, dependencies=[Depends(require_trusted_origin)]
)
async def create_staff(
    payload: StaffCreate,
    response: Response,
    current: CurrentAdmin,
    service: AdminStaffServiceDependency,
) -> StaffItem:
    prepare(response, current)
    return await service.create_staff(current, payload)


@router.patch(
    "/{user_id}", response_model=StaffItem, dependencies=[Depends(require_trusted_origin)]
)
async def update_staff(
    user_id: uuid.UUID,
    payload: StaffUpdate,
    response: Response,
    current: CurrentAdmin,
    service: AdminStaffServiceDependency,
) -> StaffItem:
    prepare(response, current)
    return await service.update_staff(current, user_id, payload)


@router.post(
    "/{user_id}/revoke-sessions",
    response_model=StaffItem,
    dependencies=[Depends(require_trusted_origin)],
)
async def revoke_sessions(
    user_id: uuid.UUID,
    payload: StaffRevoke,
    response: Response,
    current: CurrentAdmin,
    service: AdminStaffServiceDependency,
) -> StaffItem:
    prepare(response, current)
    return await service.revoke_sessions(current, user_id, payload)
