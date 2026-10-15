from pydantic import ValidationError
from pytest import MonkeyPatch, raises

from app.core.config import Environment, Settings


def test_default_settings_are_for_local_development() -> None:
    settings = Settings(_env_file=None)

    assert settings.app_name == "Responda API"
    assert settings.environment is Environment.DEVELOPMENT
    assert settings.api_v1_prefix == "/api/v1"
    assert settings.debug is True


def test_environment_variables_override_defaults(monkeypatch: MonkeyPatch) -> None:
    monkeypatch.setenv("RESPONDA_APP_NAME", "Responda Test API")
    monkeypatch.setenv("RESPONDA_ENVIRONMENT", "testing")
    monkeypatch.setenv("RESPONDA_DEBUG", "false")

    settings = Settings(_env_file=None)

    assert settings.app_name == "Responda Test API"
    assert settings.environment is Environment.TESTING
    assert settings.debug is False


def test_production_rejects_development_security_defaults() -> None:
    with raises(ValidationError):
        Settings(environment=Environment.PRODUCTION, debug=False, _env_file=None)
