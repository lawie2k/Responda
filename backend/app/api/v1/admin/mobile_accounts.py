import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.api.dependencies import CurrentAdmin, DatabaseSession, require_trusted_origin
from app.api.v1.mobile.auth import PrivateRoute
from app.core.exceptions import ApplicationError
from app.schemas.admin_mobile_accounts import (
    MobileAccountItem,
    MobileAccountList,
    MobileAccountStatusUpdate,
)
from app.services.admin_mobile_accounts import AdminMobileAccountService

router = APIRouter(prefix="/mobile-accounts", route_class=PrivateRoute)


def get_mobile_account_service(db: DatabaseSession) -> AdminMobileAccountService:
    return AdminMobileAccountService(db)


Service = Annotated[AdminMobileAccountService, Depends(get_mobile_account_service)]


@router.get("", response_model=MobileAccountList)
async def list_accounts(
    current: CurrentAdmin,
    service: Service,
    page: Annotated[int, Query(ge=1, le=100000)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 10,
    search: Annotated[str | None, Query(min_length=1, max_length=100)] = None,
    active: bool | None = None,
) -> MobileAccountList:
    AdminMobileAccountService.require_reader(current)
    return await service.list_accounts(
        current, page=page, page_size=page_size, search=search, active=active
    )


@router.patch(
    "/{user_id}/status",
    response_model=MobileAccountItem,
    dependencies=[Depends(require_trusted_origin)],
)
async def update_status(
    user_id: uuid.UUID, payload: MobileAccountStatusUpdate, current: CurrentAdmin, service: Service
) -> MobileAccountItem:
    if current.user.role != "admin":
        raise ApplicationError(
            "Only Super Admins can change account status.",
            code="account_management_forbidden",
            status_code=403,
        )
    return await service.update_status(current, user_id, payload)
