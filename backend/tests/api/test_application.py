from fastapi.testclient import TestClient

from app.core.config import Environment, Settings
from app.core.exceptions import ApplicationError
from app.db.health import DatabaseStatus, get_database_status
from app.main import create_app


async def healthy_database() -> DatabaseStatus:
    return "ok"


async def unavailable_database() -> DatabaseStatus:
    return "unavailable"


def test_openapi_document_uses_application_settings() -> None:
    settings = Settings(
        app_name="Responda Test API",
        environment=Environment.TESTING,
        debug=False,
        _env_file=None,
    )
    application = create_app(settings)
    application.dependency_overrides[get_database_status] = healthy_database

    with TestClient(application) as client:
        response = client.get("/openapi.json")

    assert response.status_code == 200
    assert response.json()["info"] == {"title": "Responda Test API", "version": "1.0.0"}


def test_health_endpoint_reports_application_status() -> None:
    settings = Settings(
        app_name="Responda Test API",
        environment=Environment.TESTING,
        debug=False,
        _env_file=None,
    )
    application = create_app(settings)
    application.dependency_overrides[get_database_status] = healthy_database

    with TestClient(application) as client:
        response = client.get("/api/v1/shared/health")

    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "service": "Responda Test API",
        "environment": "testing",
        "api_version": "1.0.0",
        "database": "ok",
    }


def test_web_development_origin_can_access_the_api() -> None:
    settings = Settings(
        environment=Environment.TESTING,
        debug=False,
        allowed_origins=["http://localhost:5173"],
        _env_file=None,
    )
    application = create_app(settings)
    application.dependency_overrides[get_database_status] = healthy_database

    with TestClient(application) as client:
        response = client.get(
            "/api/v1/shared/health",
            headers={"Origin": "http://localhost:5173"},
        )

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://localhost:5173"
    assert response.headers["access-control-allow-credentials"] == "true"


def test_health_endpoint_reports_an_unavailable_database() -> None:
    settings = Settings(environment=Environment.TESTING, debug=False, _env_file=None)
    application = create_app(settings)
    application.dependency_overrides[get_database_status] = unavailable_database

    with TestClient(application) as client:
        response = client.get("/api/v1/shared/health")

    assert response.status_code == 503
    assert response.json() == {
        "status": "degraded",
        "service": "Responda API",
        "environment": "testing",
        "api_version": "1.0.0",
        "database": "unavailable",
    }


def test_application_errors_use_a_consistent_response() -> None:
    settings = Settings(environment=Environment.TESTING, debug=False, _env_file=None)
    application = create_app(settings)

    @application.get("/test-error")
    async def raise_application_error() -> None:
        raise ApplicationError(
            "The requested test resource is unavailable.",
            code="test_resource_unavailable",
            status_code=409,
        )

    with TestClient(application) as client:
        response = client.get("/test-error")

    assert response.status_code == 409
    assert response.json() == {
        "error": {
            "code": "test_resource_unavailable",
            "message": "The requested test resource is unavailable.",
        }
    }


def test_unexpected_errors_do_not_expose_internal_details() -> None:
    settings = Settings(environment=Environment.TESTING, debug=False, _env_file=None)
    application = create_app(settings)

    @application.get("/unexpected-error")
    async def raise_unexpected_error() -> None:
        raise RuntimeError("sensitive internal detail")

    with TestClient(application, raise_server_exceptions=False) as client:
        response = client.get("/unexpected-error")

    assert response.status_code == 500
    assert response.json() == {
        "error": {
            "code": "internal_server_error",
            "message": "An unexpected error occurred.",
        }
    }
