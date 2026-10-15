from fastapi import APIRouter

from app.api.v1.admin.router import router as admin_router
from app.api.v1.mobile.router import router as mobile_router
from app.api.v1.shared.router import router as shared_router

api_router = APIRouter()
api_router.include_router(shared_router)
api_router.include_router(mobile_router)
api_router.include_router(admin_router)
