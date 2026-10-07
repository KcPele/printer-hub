"""Cursor pagination over UUIDv7 primary keys, newest first."""

import base64
import binascii
import uuid
from typing import Any

from fastapi import Query
from pydantic import BaseModel
from sqlalchemy import Select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import InstrumentedAttribute

from app.core.errors import ValidationFailedError

DEFAULT_LIMIT = 50
MAX_LIMIT = 200


class Page[T](BaseModel):
    items: list[T]
    next_cursor: str | None = None


class PageParams:
    def __init__(
        self,
        limit: int = Query(DEFAULT_LIMIT, ge=1, le=MAX_LIMIT),
        cursor: str | None = Query(None, description="`next_cursor` from the previous page"),
    ) -> None:
        self.limit = limit
        self.cursor = cursor


def encode_cursor(value: uuid.UUID) -> str:
    return base64.urlsafe_b64encode(value.bytes).decode().rstrip("=")


def decode_cursor(cursor: str) -> uuid.UUID:
    try:
        padded = cursor + "=" * (-len(cursor) % 4)
        return uuid.UUID(bytes=base64.urlsafe_b64decode(padded))
    except (ValueError, binascii.Error) as exc:
        raise ValidationFailedError(
            "pagination.invalid_cursor", "The cursor is not valid."
        ) from exc


async def paginate[M: Any](
    session: AsyncSession,
    stmt: Select[M],
    id_column: InstrumentedAttribute[uuid.UUID],
    params: PageParams,
) -> tuple[list[M], str | None]:
    """Run `stmt` newest-first and return one page plus the cursor for the next."""
    if params.cursor is not None:
        stmt = stmt.where(id_column < decode_cursor(params.cursor))
    rows = list(await session.scalars(stmt.order_by(id_column.desc()).limit(params.limit + 1)))
    if len(rows) <= params.limit:
        return rows, None
    page = rows[: params.limit]
    return page, encode_cursor(page[-1].id)
