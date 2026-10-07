from functools import lru_cache

from app.adapters.push.base import PushProvider
from app.adapters.push.fcm import FcmPushProvider
from app.adapters.push.log import LogPushProvider
from app.adapters.push.memory import MemoryPushProvider
from app.core.config import get_settings


@lru_cache
def get_push_provider() -> PushProvider:
    settings = get_settings()
    if settings.push_backend == "memory":
        return MemoryPushProvider()
    if settings.push_backend == "fcm":
        assert settings.fcm_service_account_json is not None  # noqa: S101 - checked by Settings
        return FcmPushProvider.from_json(settings.fcm_service_account_json.get_secret_value())
    return LogPushProvider()
