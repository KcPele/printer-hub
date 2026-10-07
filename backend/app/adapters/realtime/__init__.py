from functools import lru_cache

from app.adapters.realtime.base import RealtimePublisher
from app.adapters.realtime.memory import MemoryPublisher
from app.adapters.realtime.null import NullPublisher
from app.adapters.realtime.pusher import PusherPublisher
from app.core.config import get_settings


@lru_cache
def get_realtime_publisher() -> RealtimePublisher:
    settings = get_settings()
    if settings.realtime_backend == "none":
        return NullPublisher()
    if settings.realtime_backend == "memory":
        return MemoryPublisher()
    return PusherPublisher(
        base_url=settings.soketi_url,
        app_id=settings.soketi_app_id,
        key=settings.soketi_app_key,
        secret=settings.soketi_app_secret.get_secret_value(),
    )
