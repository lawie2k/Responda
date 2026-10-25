from collections.abc import Callable, Coroutine
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Request, Response
from fastapi.exceptions import RequestValidationError
from fastapi.routing import APIRoute
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.exc import SQLAlchemyError

from app.api.dependencies import DatabaseSession, SettingsDependency
from app.core.exceptions import ApplicationError
from app.core.rate_limit import LoginRateLimiter
from app.models import User
from app.schemas.mobile_auth import (
    BetaRegistration,
    MobileLogin,
    MobileProfileUpdate,
    MobileSession,
    OtpRequest,
    OtpResponse,
    OtpVerify,
)
from app.services.mobile_auth import MobileAuthService


class PrivateRoute(APIRoute):
    def get_route_handler(self) -> Callable[[Request], Coroutine[Any, Any, Response]]:
        handler = super().get_route_handler()

        async def safe(request: Request) -> Response:
            try:
                response = await handler(request)
            except RequestValidationError as error:
                raise ApplicationError(
                    "Check the submitted information.",
                    code="invalid_request",
                    status_code=422,
                    headers={"Cache-Control": "no-store"},
                ) from error
            except ApplicationError as error:
                error.headers = {**(error.headers or {}), "Cache-Control": "no-store"}
                raise
            except SQLAlchemyError:
                # SQL exceptions can contain bound phone numbers, tokens or report text.
                raise ApplicationError(
                    "The service is temporarily unavailable. Retry later.",
                    code="storage_unavailable",
                    status_code=503,
                    headers={"Cache-Control": "no-store"},
                ) from None
            response.headers["Cache-Control"] = "no-store"
            return response

        return safe


router = APIRouter(prefix="/auth", route_class=PrivateRoute)
bearer = HTTPBearer(auto_error=False)


def service(db: DatabaseSession, settings: SettingsDependency) -> MobileAuthService:
    return MobileAuthService(db, settings)


Service = Annotated[MobileAuthService, Depends(service)]


def token(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
) -> str | None:
    return credentials.credentials if credentials is not None else None


Token = Annotated[str | None, Depends(token)]


async def current_mobile_user(auth: Service, access: Token) -> User:
    user, _ = await auth.authenticate(access)
    return user


CurrentMobileUser = Annotated[User, Depends(current_mobile_user)]


async def limit(request: Request, phone: str, kind: str) -> None:
    limiter: LoginRateLimiter = getattr(request.app.state, f"mobile_{kind}_limiter")
    ip = request.client.host if request.client is not None else "unknown"
    retry = await limiter.consume(ip_address=ip, identity=phone)
    if retry is not None:
        raise ApplicationError(
            "Too many attempts. Try again later.",
            code="otp_rate_limited",
            status_code=429,
            headers={"Retry-After": str(retry)},
        )


@router.post("/otp/request", response_model=OtpResponse)
async def request_code(payload: OtpRequest, request: Request, auth: Service) -> OtpResponse:
    await limit(request, payload.phone_number, "send")
    return await auth.request_code(payload.phone_number)


@router.post("/otp/verify", response_model=MobileLogin)
async def verify(payload: OtpVerify, request: Request, auth: Service) -> MobileLogin:
    await limit(request, payload.phone_number, "verify")
    return await auth.verify(payload)


@router.get("/me", response_model=MobileSession)
async def me(auth: Service, access: Token) -> MobileSession:
    return await auth.profile(access)


@router.post("/beta/register", response_model=MobileLogin, status_code=201)
async def register_beta(payload: BetaRegistration, request: Request, auth: Service) -> MobileLogin:
    await limit(request, "beta-registration", "send")
    return await auth.register_beta(payload)


@router.patch("/profile", response_model=MobileSession)
async def profile(payload: MobileProfileUpdate, auth: Service, access: Token) -> MobileSession:
    return await auth.update_profile(access, payload)


@router.post("/logout", status_code=204)
async def logout(auth: Service, access: Token) -> None:
    await auth.logout(access)
