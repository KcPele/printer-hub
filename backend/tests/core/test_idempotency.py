import uuid
from datetime import UTC, datetime, timedelta

import pytest
from pydantic import BaseModel
from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core import idempotency
from app.core.errors import ConflictError, ValidationFailedError
from app.core.idempotency import IdempotencyRecord
from tests.factories import create_user


class _Body(BaseModel):
    name: str
    copies: int = 1


def test_fingerprint_ignores_key_order_but_not_values() -> None:
    assert idempotency.fingerprint(_Body(name="a", copies=2)) == idempotency.fingerprint(
        _Body(copies=2, name="a")
    )
    assert idempotency.fingerprint(_Body(name="a")) != idempotency.fingerprint(_Body(name="b"))


async def test_first_claim_owns_the_key_and_a_repeat_returns_the_resource(
    session: AsyncSession,
) -> None:
    user = await create_user(session)
    resource_id = uuid.uuid4()

    async def claim() -> uuid.UUID | None:
        return await idempotency.claim(
            session, user_id=user.id, scope="things.create", key="k1", request_hash="h1"
        )

    assert await claim() is None
    await idempotency.complete(
        session, user_id=user.id, scope="things.create", key="k1", resource_id=resource_id
    )

    assert await claim() == resource_id


async def test_same_key_with_a_different_request_is_rejected(session: AsyncSession) -> None:
    user = await create_user(session)
    await idempotency.claim(session, user_id=user.id, scope="s", key="k", request_hash="h1")
    await idempotency.complete(
        session, user_id=user.id, scope="s", key="k", resource_id=uuid.uuid4()
    )

    with pytest.raises(ValidationFailedError) as error:
        await idempotency.claim(session, user_id=user.id, scope="s", key="k", request_hash="h2")

    assert error.value.code == "idempotency.key_reused"


async def test_keys_are_separate_per_user_and_scope(session: AsyncSession) -> None:
    alice, bob = await create_user(session), await create_user(session)
    await idempotency.claim(session, user_id=alice.id, scope="s", key="k", request_hash="h")
    await idempotency.complete(
        session, user_id=alice.id, scope="s", key="k", resource_id=uuid.uuid4()
    )

    assert (
        await idempotency.claim(session, user_id=bob.id, scope="s", key="k", request_hash="h")
        is None
    )
    assert (
        await idempotency.claim(session, user_id=alice.id, scope="other", key="k", request_hash="h")
        is None
    )


async def test_unfinished_claim_reports_in_progress(session: AsyncSession) -> None:
    user = await create_user(session)
    await idempotency.claim(session, user_id=user.id, scope="s", key="k", request_hash="h")

    with pytest.raises(ConflictError) as error:
        await idempotency.claim(session, user_id=user.id, scope="s", key="k", request_hash="h")

    assert error.value.code == "idempotency.in_progress"


async def test_expired_key_can_be_claimed_again(session: AsyncSession) -> None:
    user = await create_user(session)
    await idempotency.claim(session, user_id=user.id, scope="s", key="k", request_hash="h1")
    await idempotency.complete(
        session, user_id=user.id, scope="s", key="k", resource_id=uuid.uuid4()
    )
    await session.execute(
        update(IdempotencyRecord).values(expires_at=datetime.now(UTC) - timedelta(seconds=1))
    )

    assert (
        await idempotency.claim(session, user_id=user.id, scope="s", key="k", request_hash="h2")
        is None
    )
