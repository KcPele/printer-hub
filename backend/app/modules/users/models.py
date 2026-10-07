from datetime import datetime
from typing import Any

from sqlalchemy import String, false, text, true
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, IdMixin, TimestampMixin


class User(Base, IdMixin, TimestampMixin):
    __tablename__ = "users"

    # Stored lowercased; see `users.service.normalize_email`.
    email: Mapped[str] = mapped_column(String(320), unique=True)
    # Null until the user proves they receive mail at `email`.
    email_verified_at: Mapped[datetime | None]
    password_hash: Mapped[str] = mapped_column(String(255))
    name: Mapped[str] = mapped_column(String(200))
    preferences: Mapped[dict[str, Any]] = mapped_column(
        default=dict, server_default=text("'{}'::jsonb")
    )
    is_active: Mapped[bool] = mapped_column(default=True, server_default=true())
    # Platform operator: manages feature flags and the capability registry.
    is_superuser: Mapped[bool] = mapped_column(default=False, server_default=false())
