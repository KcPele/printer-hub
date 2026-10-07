"""Application settings, loaded from `PRINTERHUB_*` environment variables."""

from functools import lru_cache
from typing import Literal, Self

from pydantic import SecretStr, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

# Development-only defaults. `Settings` refuses to start with these outside local and test.
_DEV_SECRET_KEY = "dev-only-secret-key-change-me-0123456789abcdef"  # noqa: S105
_DEV_ENCRYPTION_KEY = "Rm91hMg3qrza2TmING-MHs64-xWne_tBvZy8q9dVJ0Q="

Environment = Literal["local", "test", "staging", "production"]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="PRINTERHUB_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    environment: Environment = "local"
    log_level: str = "INFO"
    log_json: bool = True
    cors_origins: list[str] = []

    database_url: str = "postgresql+asyncpg://printerhub:printerhub@localhost:5433/printerhub"
    database_pool_size: int = 10
    redis_url: str = "redis://localhost:6380/0"
    # "arq" queues background work in Redis for the worker process.
    tasks_backend: Literal["arq", "memory"] = "arq"

    secret_key: SecretStr = SecretStr(_DEV_SECRET_KEY)
    credentials_encryption_key: SecretStr = SecretStr(_DEV_ENCRYPTION_KEY)

    access_token_ttl_seconds: int = 15 * 60
    refresh_token_ttl_days: int = 30
    invitation_ttl_days: int = 7
    pairing_token_ttl_seconds: int = 10 * 60
    idempotency_ttl_hours: int = 24

    login_rate_limit_attempts: int = 10
    login_rate_limit_window_seconds: int = 5 * 60
    register_rate_limit_attempts: int = 20
    register_rate_limit_window_seconds: int = 60 * 60

    storage_backend: Literal["s3", "memory"] = "s3"
    s3_endpoint_url: str | None = "http://localhost:9000"
    # Host that clients use to reach object storage, when it differs from the
    # endpoint the backend itself uses (for example inside Docker Compose).
    s3_public_endpoint_url: str | None = None
    s3_region: str = "us-east-1"
    s3_access_key: SecretStr = SecretStr("printerhub")
    s3_secret_key: SecretStr = SecretStr("printerhub-dev-secret")
    s3_bucket: str = "printerhub-documents"
    s3_presign_ttl_seconds: int = 15 * 60
    max_document_size_bytes: int = 200 * 1024 * 1024

    # "log" writes pushes to the log; "fcm" sends through Firebase Cloud
    # Messaging, which reaches Android directly and iOS through APNs.
    push_backend: Literal["log", "fcm", "memory"] = "log"
    fcm_service_account_json: SecretStr | None = None

    @property
    def is_production_like(self) -> bool:
        return self.environment in ("staging", "production")

    @model_validator(mode="after")
    def _reject_dev_secrets_in_production(self) -> Self:
        if not self.is_production_like:
            return self
        if self.secret_key.get_secret_value() == _DEV_SECRET_KEY:
            raise ValueError("PRINTERHUB_SECRET_KEY must be set outside local and test")
        if self.credentials_encryption_key.get_secret_value() == _DEV_ENCRYPTION_KEY:
            raise ValueError(
                "PRINTERHUB_CREDENTIALS_ENCRYPTION_KEY must be set outside local and test"
            )
        if self.push_backend == "fcm" and self.fcm_service_account_json is None:
            raise ValueError("PRINTERHUB_FCM_SERVICE_ACCOUNT_JSON is required when push is fcm")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
