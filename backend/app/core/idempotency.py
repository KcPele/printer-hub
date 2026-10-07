"""Idempotency keys for requests that create resources (FR-PRN-022, FRD §47).

A client sends `Idempotency-Key` with a create request. The key is claimed in
the same transaction that creates the resource, so either both exist or
neither does. A retry with the same key and body gets the resource that the
first request created instead of a duplicate.
"""

import hashlib
import json
import uuid
from datetime import UTC, datetime, timedelta
from typing import Annotated

from fastapi import Depends, Header
from pydantic import BaseModel
from sqlalchemy import ForeignKey, String, UniqueConstraint, delete, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Mapped, mapped_column

from app.core.config import get_settings
from app.core.db import Base, CreatedAtMixin, IdMixin
from app.core.errors import BadRequestError, ConflictError, ValidationFailedError

IDEMPOTENCY_HEADER = "Idempotency-Key"
REPLAYED_HEADER = "Idempotent-Replayed"
# Also marks the header as required in the published contract; see `app.main`.
REQUIRED_KEY_DESCRIPTION = "Unique per logical request. Reuse it when retrying."


class IdempotencyRecord(Base, IdMixin, CreatedAtMixin):
    __tablename__ = "idempotency_keys"
    __table_args__ = (UniqueConstraint("user_id", "scope", "key"),)

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    # Names the operation, so one key cannot collide across endpoints.
    scope: Mapped[str] = mapped_column(String(100))
    key: Mapped[str] = mapped_column(String(255))
    request_hash: Mapped[str] = mapped_column(String(64))
    resource_id: Mapped[uuid.UUID | None]
    expires_at: Mapped[datetime] = mapped_column(index=True)


def fingerprint(payload: BaseModel) -> str:
    """Stable hash of a request body, used to detect a key reused for a different request."""
    canonical = json.dumps(payload.model_dump(mode="json"), sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canonical.encode()).hexdigest()


async def claim(
    session: AsyncSession, *, user_id: uuid.UUID, scope: str, key: str, request_hash: str
) -> uuid.UUID | None:
    """Claim `key` for this request.

    Returns None when the caller now owns the key and should do the work, then
    call `complete`. Returns the resource ID when an earlier request with the
    same key and body already did it.
    """
    now = datetime.now(UTC)
    expires_at = now + timedelta(hours=get_settings().idempotency_ttl_hours)
    # ON CONFLICT waits for a concurrent transaction holding the same key to
    # finish, so two simultaneous requests cannot both proceed.
    inserted = await session.scalar(
        insert(IdempotencyRecord)
        .values(
            user_id=user_id,
            scope=scope,
            key=key,
            request_hash=request_hash,
            expires_at=expires_at,
        )
        .on_conflict_do_nothing(index_elements=["user_id", "scope", "key"])
        .returning(IdempotencyRecord.id)
    )
    if inserted is not None:
        return None

    record = await session.scalar(
        select(IdempotencyRecord)
        .where(
            IdempotencyRecord.user_id == user_id,
            IdempotencyRecord.scope == scope,
            IdempotencyRecord.key == key,
        )
        .with_for_update()
        .execution_options(populate_existing=True)
    )
    if record is None or record.expires_at <= now:
        # The earlier claim rolled back or expired: take the key over.
        if record is None:
            return await claim(
                session, user_id=user_id, scope=scope, key=key, request_hash=request_hash
            )
        record.request_hash = request_hash
        record.resource_id = None
        record.expires_at = expires_at
        await session.flush()
        return None
    if record.request_hash != request_hash:
        raise ValidationFailedError(
            "idempotency.key_reused",
            "This Idempotency-Key was already used with a different request.",
        )
    if record.resource_id is None:
        raise ConflictError(
            "idempotency.in_progress", "A request with this Idempotency-Key is still running."
        )
    return record.resource_id


async def complete(
    session: AsyncSession, *, user_id: uuid.UUID, scope: str, key: str, resource_id: uuid.UUID
) -> None:
    """Record the resource created under a claimed key."""
    record = await session.scalar(
        select(IdempotencyRecord).where(
            IdempotencyRecord.user_id == user_id,
            IdempotencyRecord.scope == scope,
            IdempotencyRecord.key == key,
        )
    )
    assert record is not None  # noqa: S101 - `claim` inserted it in this transaction
    record.resource_id = resource_id
    await session.flush()


async def purge_expired(session: AsyncSession) -> None:
    await session.execute(
        delete(IdempotencyRecord).where(IdempotencyRecord.expires_at <= datetime.now(UTC))
    )


def require_idempotency_key(
    key: Annotated[
        str | None,
        Header(
            alias=IDEMPOTENCY_HEADER,
            min_length=1,
            max_length=255,
            description=REQUIRED_KEY_DESCRIPTION,
        ),
    ] = None,
) -> str:
    if key is None:
        raise BadRequestError(
            "idempotency.key_required", f"Send an {IDEMPOTENCY_HEADER} header with this request."
        )
    return key


IdempotencyKey = Annotated[str, Depends(require_idempotency_key)]
