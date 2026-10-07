import uuid
from collections.abc import Sequence

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.users.models import User
from app.modules.users.schemas import UserUpdate


def normalize_email(email: str) -> str:
    return email.strip().lower()


async def get_by_id(session: AsyncSession, user_id: uuid.UUID) -> User | None:
    return await session.get(User, user_id)


async def get_by_email(session: AsyncSession, email: str) -> User | None:
    result: User | None = await session.scalar(
        select(User).where(User.email == normalize_email(email))
    )
    return result


async def get_many(session: AsyncSession, user_ids: Sequence[uuid.UUID]) -> dict[uuid.UUID, User]:
    if not user_ids:
        return {}
    users = await session.scalars(select(User).where(User.id.in_(user_ids)))
    return {user.id: user for user in users}


async def update_profile(session: AsyncSession, user: User, payload: UserUpdate) -> User:
    if payload.name is not None:
        user.name = payload.name
    if payload.preferences is not None:
        user.preferences = payload.preferences.model_dump(mode="json")
    await session.flush()
    return user
