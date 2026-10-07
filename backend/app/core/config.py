"""Application settings, loaded from `PRINTERHUB_*` environment variables."""

import base64
import binascii
import json
from functools import lru_cache
from typing import Literal, Self

from pydantic import SecretStr, field_validator, model_validator
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
    # "arq" queues background work in Redis for the worker.
    tasks_backend: Literal["arq", "memory"] = "arq"
    # Run the worker inside the API process, so one container is the whole
    # backend. Turn off when running `arq app.worker.WorkerSettings` separately.
    embedded_worker: bool = True

    secret_key: SecretStr = SecretStr(_DEV_SECRET_KEY)
    credentials_encryption_key: SecretStr = SecretStr(_DEV_ENCRYPTION_KEY)

    access_token_ttl_seconds: int = 15 * 60
    refresh_token_ttl_days: int = 30
    invitation_ttl_days: int = 7
    pairing_token_ttl_seconds: int = 10 * 60
    idempotency_ttl_hours: int = 24

    # One-time codes emailed for password reset and email verification.
    email_code_ttl_minutes: int = 15
    email_code_max_attempts: int = 5
    email_code_rate_limit_attempts: int = 5
    email_code_rate_limit_window_seconds: int = 60 * 60

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

    # "log" writes emails to the log; "smtp" sends them through any SMTP server.
    email_backend: Literal["log", "smtp", "memory"] = "log"
    email_from: str = "PrinterHub <no-reply@printerhub.local>"
    smtp_host: str | None = None
    smtp_port: int = 587
    smtp_username: str | None = None
    smtp_password: SecretStr | None = None
    # "starttls" upgrades a plain connection (port 587); "ssl" connects encrypted (port 465).
    smtp_security: Literal["starttls", "ssl", "none"] = "starttls"

    # "log" writes pushes to the log; "fcm" sends through Firebase Cloud
    # Messaging, which reaches Android directly and iOS through APNs.
    push_backend: Literal["log", "fcm", "memory"] = "log"
    # The Firebase service-account key, as JSON or as base64 of that JSON.
    fcm_service_account_json: SecretStr | None = None

    @field_validator("database_url")
    @classmethod
    def _use_async_driver(cls, value: str) -> str:
        """Accept the URL forms hosting providers hand out and select the asyncpg driver."""
        for prefix in ("postgres://", "postgresql://"):
            if value.startswith(prefix):
                value = "postgresql+asyncpg://" + value[len(prefix) :]
        # libpq spells the TLS option `sslmode`; asyncpg calls it `ssl`.
        return value.replace("?sslmode=", "?ssl=").replace("&sslmode=", "&ssl=")

    @field_validator("fcm_service_account_json")
    @classmethod
    def _decode_service_account(cls, value: SecretStr | None) -> SecretStr | None:
        """Accept the key as JSON or base64, and check it is the right kind of file."""
        if value is None or not value.get_secret_value().strip():
            return None
        raw = value.get_secret_value().strip()
        if not raw.startswith("{"):
            try:
                raw = base64.b64decode(raw, validate=True).decode()
            except (binascii.Error, UnicodeDecodeError) as exc:
                raise ValueError("must be the service-account JSON or base64 of it") from exc
        try:
            account = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise ValueError("is not valid JSON") from exc
        if "project_info" in account:
            raise ValueError(
                "is google-services.json, the Android app config. The backend needs the "
                "service-account key: Firebase console > Project settings > Service accounts "
                "> Generate new private key"
            )
        missing = {"project_id", "client_email", "private_key"} - account.keys()
        if missing:
            raise ValueError(f"is missing {sorted(missing)}; it is not a service-account key")
        return SecretStr(raw)

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
        return self

    @model_validator(mode="after")
    def _require_smtp_host(self) -> Self:
        if self.email_backend == "smtp" and not self.smtp_host:
            raise ValueError("PRINTERHUB_SMTP_HOST is required when PRINTERHUB_EMAIL_BACKEND=smtp")
        return self

    @model_validator(mode="after")
    def _require_fcm_credentials(self) -> Self:
        if self.push_backend == "fcm" and self.fcm_service_account_json is None:
            raise ValueError(
                "PRINTERHUB_FCM_SERVICE_ACCOUNT_JSON is required when PRINTERHUB_PUSH_BACKEND=fcm"
            )
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
