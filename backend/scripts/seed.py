"""Load reference data. Safe to run repeatedly.

python -m scripts.seed
"""

import asyncio

from app.adapters.storage import get_object_storage
from app.adapters.storage.s3 import S3Storage
from app.core.config import get_settings
from app.core.db import get_engine, get_session_factory, session_scope
from app.modules.capabilities import service as capabilities
from app.modules.feature_flags import service as feature_flags


async def main() -> None:
    async with session_scope(get_session_factory()) as session:
        profiles = await capabilities.seed_built_in_profiles(session)
        flags = await feature_flags.seed_built_in_flags(session)
    print(f"Capability profiles added or updated: {profiles}")
    print(f"Feature flags added: {flags}")

    # Production buckets are provisioned by infrastructure, not by the app.
    storage = get_object_storage()
    if get_settings().environment == "local" and isinstance(storage, S3Storage):
        await storage.ensure_bucket()
        print(f"Bucket ready: {get_settings().s3_bucket}")

    await get_engine().dispose()


if __name__ == "__main__":
    asyncio.run(main())
