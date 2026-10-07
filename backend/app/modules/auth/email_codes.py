"""One-time codes sent by email, for password reset and email verification.

A code is six digits, typed into the app. That is short enough to guess, so
three limits make guessing useless: it expires quickly, it dies after a few
wrong attempts, and only a keyed hash of it is stored.
"""

import enum
import hashlib
import hmac
import secrets
import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import ForeignKey, String, delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Mapped, mapped_column

from app.core.config import get_settings
from app.core.db import Base, CreatedAtMixin, IdMixin, str_enum

CODE_LENGTH = 6


class CodePurpose(enum.StrEnum):
    PASSWORD_RESET = "password_reset"  # noqa: S105
    EMAIL_VERIFICATION = "email_verification"


class EmailCode(Base, IdMixin, CreatedAtMixin):
    __tablename__ = "email_codes"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    purpose: Mapped[CodePurpose] = mapped_column(str_enum(CodePurpose))
    code_hash: Mapped[str] = mapped_column(String(64))
    expires_at: Mapped[datetime]
    attempts: Mapped[int] = mapped_column(default=0)
    consumed_at: Mapped[datetime | None]


def _hash(user_id: uuid.UUID, purpose: CodePurpose, code: str) -> str:
    # Keyed with the server secret: a leaked table alone cannot be brute-forced,
    # even though a code has only a million possible values.
    key = get_settings().secret_key.get_secret_value().encode()
    message = f"{purpose.value}:{user_id}:{code}".encode()
    return hmac.new(key, message, hashlib.sha256).hexdigest()


async def issue(session: AsyncSession, *, user_id: uuid.UUID, purpose: CodePurpose) -> str:
    """Create a code, replacing any earlier one for the same purpose. Returns the code."""
    await session.execute(
        delete(EmailCode).where(EmailCode.user_id == user_id, EmailCode.purpose == purpose)
    )
    code = f"{secrets.randbelow(10**CODE_LENGTH):0{CODE_LENGTH}d}"
    session.add(
        EmailCode(
            user_id=user_id,
            purpose=purpose,
            code_hash=_hash(user_id, purpose, code),
            expires_at=datetime.now(UTC) + timedelta(minutes=get_settings().email_code_ttl_minutes),
        )
    )
    await session.flush()
    return code


async def redeem(
    session: AsyncSession, *, user_id: uuid.UUID, purpose: CodePurpose, code: str
) -> bool:
    """Check `code` and use it up. A wrong guess counts against the code.

    The caller must commit when this returns False, so the failed attempt is
    recorded even though the request itself fails.
    """
    record = await session.scalar(
        select(EmailCode)
        .where(
            EmailCode.user_id == user_id,
            EmailCode.purpose == purpose,
            EmailCode.consumed_at.is_(None),
        )
        .with_for_update()
    )
    if (
        record is None
        or record.expires_at <= datetime.now(UTC)
        or record.attempts >= get_settings().email_code_max_attempts
    ):
        return False
    if not hmac.compare_digest(record.code_hash, _hash(user_id, purpose, code)):
        record.attempts += 1
        await session.flush()
        return False
    record.consumed_at = datetime.now(UTC)
    await session.flush()
    return True


async def purge_expired(session: AsyncSession) -> None:
    await session.execute(delete(EmailCode).where(EmailCode.expires_at <= datetime.now(UTC)))
