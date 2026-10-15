from fastapi import APIRouter

from app.api.v1.admin.auth import router as auth_router

router = APIRouter(prefix="/admin", tags=["admin"])
router.include_router(auth_router)
