"""Make an existing account a platform administrator.

    python -m scripts.promote_superuser someone@example.com

Platform administrators manage feature flags and the capability registry.
"""

import asyncio
import sys

from app.core.db import get_engine, get_session_factory, session_scope
from app.modules.users import service as users


async def main(email: str) -> int:
    async with session_scope(get_session_factory()) as session:
        user = await users.get_by_email(session, email)
        if user is None:
            print(f"No account with email {email}. Register it first.")
            return 1
        user.is_superuser = True
    print(f"{email} is now a platform administrator.")
    await get_engine().dispose()
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(asyncio.run(main(sys.argv[1])))
