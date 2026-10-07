"""Builders for test data. Each inserts and flushes, so rows are visible to API calls."""

import uuid
from datetime import UTC, datetime, timedelta
from functools import lru_cache
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token, generate_token, hash_password, hash_token
from app.modules.auth.models import UserSession
from app.modules.users.models import User

PASSWORD = "correct-horse-battery"


@lru_cache
def _password_hash() -> str:
    # Argon2 is deliberately slow; hash the shared test password once.
    return hash_password(PASSWORD)


def unique_email(prefix: str = "user") -> str:
    return f"{prefix}-{uuid.uuid4().hex[:10]}@example.com"


async def create_user(session: AsyncSession, **overrides: Any) -> User:
    values: dict[str, Any] = {
        "email": unique_email(),
        "password_hash": _password_hash(),
        "name": "Test User",
    }
    values.update(overrides)
    user = User(**values)
    session.add(user)
    await session.flush()
    return user


async def auth_headers(session: AsyncSession, user: User) -> dict[str, str]:
    """Open a session for `user` and return its Authorization header."""
    user_session = UserSession(
        user_id=user.id,
        refresh_token_hash=hash_token(generate_token()),
        expires_at=datetime.now(UTC) + timedelta(days=1),
    )
    session.add(user_session)
    await session.flush()
    token, _ = create_access_token(user.id, user_session.id)
    return {"Authorization": f"Bearer {token}"}
