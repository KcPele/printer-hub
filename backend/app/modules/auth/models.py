import uuid
from datetime import datetime

from sqlalchemy import ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, CreatedAtMixin, IdMixin


class UserSession(Base, IdMixin, CreatedAtMixin):
    """A signed-in client. Revoking the row invalidates its access tokens at once."""

    __tablename__ = "sessions"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    device_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("devices.id", ondelete="SET NULL")
    )
    refresh_token_hash: Mapped[str] = mapped_column(String(64), unique=True)
    # The token this session rotated away from. Seeing it again means the
    # refresh token was stolen or replayed.
    previous_refresh_token_hash: Mapped[str | None] = mapped_column(String(64), index=True)
    user_agent: Mapped[str | None] = mapped_column(String(500))
    ip: Mapped[str | None] = mapped_column(String(64))
    expires_at: Mapped[datetime]
    last_used_at: Mapped[datetime] = mapped_column(server_default=func.now())
    revoked_at: Mapped[datetime | None]

    def is_usable(self, now: datetime) -> bool:
        return self.revoked_at is None and self.expires_at > now
