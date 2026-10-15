from fastapi import APIRouter

from app.api.v1.shared.health import router as health_router

router = APIRouter(prefix="/shared", tags=["shared"])
router.include_router(health_router)
