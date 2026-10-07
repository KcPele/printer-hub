import base64
import json

import pytest
from pydantic import ValidationError

from app.core.config import Settings


def _settings(**overrides: object) -> Settings:
    return Settings(_env_file=None, **overrides)  # type: ignore[arg-type]


@pytest.mark.parametrize(
    ("given", "expected"),
    [
        (
            "postgres://u:p@db.example.com:5432/app",
            "postgresql+asyncpg://u:p@db.example.com:5432/app",
        ),
        ("postgresql://u:p@db/app?sslmode=require", "postgresql+asyncpg://u:p@db/app?ssl=require"),
        ("postgresql+asyncpg://u:p@db/app", "postgresql+asyncpg://u:p@db/app"),
    ],
)
def test_database_url_is_normalized_to_the_async_driver(given: str, expected: str) -> None:
    assert _settings(database_url=given).database_url == expected


def test_production_refuses_development_secrets() -> None:
    with pytest.raises(ValidationError, match="PRINTERHUB_SECRET_KEY"):
        _settings(environment="production")

    with pytest.raises(ValidationError, match="PRINTERHUB_CREDENTIALS_ENCRYPTION_KEY"):
        _settings(environment="production", secret_key="a-real-secret-key-of-sufficient-length")


def test_production_starts_with_real_secrets() -> None:
    settings = _settings(
        environment="production",
        secret_key="a-real-secret-key-of-sufficient-length",
        credentials_encryption_key="kq9rJk3x2mFvQ0n5hT8yWcZ1bL4sD7gA6eU9iO2pR5M=",
    )

    assert settings.is_production_like


def test_fcm_backend_requires_a_service_account() -> None:
    with pytest.raises(ValidationError, match="FCM_SERVICE_ACCOUNT_JSON"):
        _settings(push_backend="fcm")


_SERVICE_ACCOUNT = {
    "type": "service_account",
    "project_id": "demo",
    "client_email": "push@demo.iam.gserviceaccount.com",
    "private_key": "-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----\n",
}


def test_service_account_is_accepted_as_json_or_base64() -> None:
    as_json = json.dumps(_SERVICE_ACCOUNT)
    as_base64 = base64.b64encode(as_json.encode()).decode()

    for value in (as_json, as_base64, f"  {as_base64}\n"):
        settings = _settings(push_backend="fcm", fcm_service_account_json=value)
        assert settings.fcm_service_account_json is not None
        assert json.loads(settings.fcm_service_account_json.get_secret_value()) == _SERVICE_ACCOUNT


def test_android_app_config_is_rejected_with_directions() -> None:
    google_services = json.dumps({"project_info": {"project_id": "demo"}, "client": []})

    with pytest.raises(ValidationError, match="Service accounts"):
        _settings(fcm_service_account_json=google_services)


def test_garbage_service_account_is_rejected() -> None:
    with pytest.raises(ValidationError, match="base64"):
        _settings(fcm_service_account_json="not json, not base64!")
    with pytest.raises(ValidationError, match="not a service-account key"):
        _settings(fcm_service_account_json=json.dumps({"project_id": "demo"}))


def test_blank_service_account_means_not_configured() -> None:
    assert _settings(fcm_service_account_json="").fcm_service_account_json is None


def test_smtp_backend_requires_a_host() -> None:
    with pytest.raises(ValidationError, match="PRINTERHUB_SMTP_HOST"):
        _settings(email_backend="smtp")

    assert _settings(email_backend="smtp", smtp_host="smtp.example.com").smtp_port == 587
