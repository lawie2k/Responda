from collections.abc import Callable, Coroutine
from datetime import UTC, datetime
from typing import Any

from fastapi import APIRouter, Depends, Request, Response, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.routing import APIRoute

from app.api.dependencies import (
    AdminAuthServiceDependency,
    CurrentAdmin,
    LoginRateLimiterDependency,
    PasswordRateLimiterDependency,
    SettingsDependency,
    require_trusted_origin,
)
from app.core.exceptions import ApplicationError
from app.core.security import normalize_email
from app.schemas.admin_auth import (
    AdminLoginRequest,
    AdminPasswordChangeRequest,
    AdminSessionResponse,
    AdminUserResponse,
)


class AuthRoute(APIRoute):
    def get_route_handler(self) -> Callable[[Request], Coroutine[Any, Any, Response]]:
        handler = super().get_route_handler()

        async def safe_handler(request: Request) -> Response:
            try:
                return await handler(request)
            except ApplicationError as error:
                error.headers = {**(error.headers or {}), "Cache-Control": "no-store, max-age=0"}
                raise
            except RequestValidationError:
                return JSONResponse(
                    status_code=422,
                    content={
                        "error": {
                            "code": "invalid_auth_request",
                            "message": "Check the account fields and password requirements.",
                        }
                    },
                    headers={"Cache-Control": "no-store, max-age=0"},
                )

        return safe_handler


router = APIRouter(prefix="/auth", route_class=AuthRoute)


def _prevent_response_caching(response: Response) -> None:
    response.headers["Cache-Control"] = "no-store, max-age=0"
    response.headers["Pragma"] = "no-cache"


def _client_ip(request: Request, *, trust_proxy_headers: bool) -> str:
    if trust_proxy_headers:
        forwarded_for = request.headers.get("x-forwarded-for")
        if forwarded_for:
            return forwarded_for.split(",", maxsplit=1)[0].strip()[:45]
    return request.client.host[:45] if request.client is not None else "unknown"


def _device_name(request: Request) -> str | None:
    user_agent = request.headers.get("user-agent")
    return user_agent[:150] if user_agent else None


@router.post(
    "/login",
    response_model=AdminSessionResponse,
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(require_trusted_origin)],
    summary="Start a staff dashboard session",
)
async def login(
    payload: AdminLoginRequest,
    request: Request,
    response: Response,
    service: AdminAuthServiceDependency,
    settings: SettingsDependency,
    rate_limiter: LoginRateLimiterDependency,
) -> AdminSessionResponse:
    _prevent_response_caching(response)
    ip_address = _client_ip(request, trust_proxy_headers=settings.trust_proxy_headers)
    retry_after = await rate_limiter.consume(
        ip_address=ip_address,
        identity=normalize_email(payload.email),
    )
    if retry_after is not None:
        raise ApplicationError(
            "Too many login attempts. Try again later.",
            code="login_rate_limited",
            status_code=429,
            headers={"Retry-After": str(retry_after)},
        )

    result = await service.login(
        email=payload.email,
        password=payload.password.get_secret_value(),
        ip_address=ip_address,
        device_name=_device_name(request),
    )
    response.set_cookie(
        key=settings.admin_session_cookie_name,
        value=result.token,
        max_age=settings.admin_session_ttl_seconds,
        httponly=True,
        secure=settings.admin_session_cookie_secure,
        samesite="lax",
        path="/api/v1/admin",
    )
    return AdminSessionResponse(
        user=AdminUserResponse.model_validate(result.user),
        expires_at=result.session.expires_at,
    )


@router.get(
    "/me",
    response_model=AdminSessionResponse,
    status_code=status.HTTP_200_OK,
    summary="Get the current staff session",
)
async def get_current_session(
    response: Response,
    current: CurrentAdmin,
) -> AdminSessionResponse:
    _prevent_response_caching(response)
    return AdminSessionResponse(
        user=AdminUserResponse.model_validate(current.user),
        expires_at=current.session.expires_at,
    )


@router.post(
    "/change-password",
    response_model=AdminSessionResponse,
    dependencies=[Depends(require_trusted_origin)],
    summary="Change the signed-in administrator's password",
)
async def change_password(
    payload: AdminPasswordChangeRequest,
    request: Request,
    response: Response,
    current: CurrentAdmin,
    service: AdminAuthServiceDependency,
    settings: SettingsDependency,
    rate_limiter: PasswordRateLimiterDependency,
) -> AdminSessionResponse:
    _prevent_response_caching(response)
    ip_address = _client_ip(request, trust_proxy_headers=settings.trust_proxy_headers)
    retry_after = await rate_limiter.consume(
        ip_address=ip_address,
        identity=str(current.user.user_id),
    )
    if retry_after is not None:
        raise ApplicationError(
            "Too many password change attempts. Try again later.",
            code="password_change_rate_limited",
            status_code=429,
            headers={"Retry-After": str(retry_after)},
        )
    result = await service.change_password(
        current,
        current_password=payload.current_password.get_secret_value(),
        new_password=payload.new_password.get_secret_value(),
        ip_address=ip_address,
    )
    response.set_cookie(
        key=settings.admin_session_cookie_name,
        value=result.token,
        max_age=max(0, int((result.session.expires_at - datetime.now(UTC)).total_seconds())),
        httponly=True,
        secure=settings.admin_session_cookie_secure,
        samesite="lax",
        path="/api/v1/admin",
    )
    return AdminSessionResponse(
        user=AdminUserResponse.model_validate(result.user),
        expires_at=result.session.expires_at,
    )


@router.post(
    "/logout",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(require_trusted_origin)],
    summary="End the current staff session",
)
async def logout(
    request: Request,
    response: Response,
    current: CurrentAdmin,
    service: AdminAuthServiceDependency,
    settings: SettingsDependency,
) -> None:
    _prevent_response_caching(response)
    ip_address = _client_ip(request, trust_proxy_headers=settings.trust_proxy_headers)
    await service.logout(current, ip_address=ip_address)
    response.delete_cookie(
        key=settings.admin_session_cookie_name,
        path="/api/v1/admin",
        httponly=True,
        secure=settings.admin_session_cookie_secure,
        samesite="lax",
    )
