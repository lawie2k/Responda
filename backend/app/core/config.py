from enum import StrEnum
from functools import lru_cache

from pydantic import Field, SecretStr, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Environment(StrEnum):
    DEVELOPMENT = "development"
    TESTING = "testing"
    STAGING = "staging"
    PRODUCTION = "production"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        env_prefix="RESPONDA_",
        case_sensitive=False,
        extra="ignore",
    )

    app_name: str = "Responda API"
    environment: Environment = Environment.DEVELOPMENT
    debug: bool = True
    api_version: str = "1.0.0"
    api_v1_prefix: str = "/api/v1"
    secret_key: SecretStr = SecretStr("development-only-change-me")
    database_url: str = "postgresql+psycopg://postgres:postgres@localhost:5432/responda"
    database_pool_size: int = Field(default=5, ge=1)
    database_max_overflow: int = Field(default=10, ge=0)
    database_connect_timeout_seconds: int = Field(default=5, ge=1, le=60)
    admin_session_cookie_name: str = "responda_admin_session"
    admin_session_cookie_secure: bool = False
    admin_session_ttl_seconds: int = Field(default=8 * 60 * 60, ge=300, le=7 * 24 * 60 * 60)
    admin_max_sessions_per_user: int = Field(default=5, ge=1, le=20)
    admin_login_rate_limit_attempts: int = Field(default=5, ge=1, le=100)
    admin_login_rate_limit_window_seconds: int = Field(default=60, ge=10, le=3600)
    trust_proxy_headers: bool = False
    mobile_dev_otp_enabled: bool = False
    mobile_session_ttl_seconds: int = Field(default=30 * 24 * 60 * 60, ge=300, le=2592000)
    allowed_origins: list[str] = Field(
        default_factory=lambda: [
            "http://localhost:3000",
            "http://127.0.0.1:3000",
            "http://localhost:5173",
            "http://127.0.0.1:5173",
        ]
    )

    @field_validator("api_v1_prefix")
    @classmethod
    def validate_api_prefix(cls, value: str) -> str:
        normalized = value.rstrip("/")
        if not normalized.startswith("/"):
            raise ValueError("API prefix must start with '/'")
        return normalized

    @model_validator(mode="after")
    def validate_deployment_settings(self) -> "Settings":
        if "*" in self.allowed_origins:
            raise ValueError("Wildcard CORS origins are not allowed when credentials are enabled")
        if self.environment in {Environment.STAGING, Environment.PRODUCTION}:
            if self.mobile_dev_otp_enabled:
                raise ValueError("Development OTP must be disabled outside local environments")
            secret_key = self.secret_key.get_secret_value()
            if secret_key == "development-only-change-me" or len(secret_key) < 32:
                raise ValueError("A secure secret key is required outside development and testing")
            if self.debug:
                raise ValueError("Debug mode must be disabled outside development and testing")
            if not self.admin_session_cookie_secure:
                raise ValueError(
                    "Secure admin session cookies are required outside local environments"
                )
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
