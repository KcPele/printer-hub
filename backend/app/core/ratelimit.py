"""Fixed-window rate limiting in Redis."""

from app.core.errors import RateLimitedError
from app.core.redis import get_redis


async def enforce_rate_limit(
    bucket: str, identifier: str, *, limit: int, window_seconds: int
) -> None:
    """Count one attempt and raise `RateLimitedError` once `limit` is exceeded in the window."""
    redis = get_redis()
    key = f"ratelimit:{bucket}:{identifier}"
    count = await redis.incr(key)
    if count == 1:
        await redis.expire(key, window_seconds)
    if count > limit:
        ttl = await redis.ttl(key)
        raise RateLimitedError(retry_after_seconds=max(ttl, 1))
