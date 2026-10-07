from functools import lru_cache

from app.adapters.storage.base import ObjectStorage
from app.adapters.storage.memory import MemoryStorage
from app.adapters.storage.s3 import S3Storage
from app.core.config import get_settings


@lru_cache
def get_object_storage() -> ObjectStorage:
    settings = get_settings()
    if settings.storage_backend == "memory":
        return MemoryStorage()
    return S3Storage(
        bucket=settings.s3_bucket,
        region=settings.s3_region,
        access_key=settings.s3_access_key.get_secret_value(),
        secret_key=settings.s3_secret_key.get_secret_value(),
        endpoint_url=settings.s3_endpoint_url,
        public_endpoint_url=settings.s3_public_endpoint_url,
    )
