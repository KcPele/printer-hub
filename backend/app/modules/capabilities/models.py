from typing import Any

from sqlalchemy import String, UniqueConstraint, text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, IdMixin, TimestampMixin, str_enum
from app.modules.capabilities.schemas import ProfileCategory


class CapabilityProfile(Base, IdMixin, TimestampMixin):
    """Vendor baseline for a printer family (FRD §55.1 item 19).

    A profile tells clients what a model is expected to support and what to
    probe for. It never overrides what a device actually reports.
    """

    __tablename__ = "capability_profiles"
    __table_args__ = (UniqueConstraint("manufacturer", "display_name"),)

    manufacturer: Mapped[str] = mapped_column(String(100), index=True)
    display_name: Mapped[str] = mapped_column(String(200))
    model_patterns: Mapped[list[str]]
    capabilities: Mapped[dict[str, Any]]
    optional_features: Mapped[list[str]] = mapped_column(default=list)
    notes: Mapped[list[str]] = mapped_column(default=list)
    # What the catalogue shows: the kind of machine, a line about it, how far up the
    # list it belongs, and what to do on the printer before adding it.
    category: Mapped[ProfileCategory] = mapped_column(
        str_enum(ProfileCategory),
        default=ProfileCategory.OFFICE_MULTIFUNCTION,
        server_default=ProfileCategory.OFFICE_MULTIFUNCTION.value,
    )
    summary: Mapped[str | None] = mapped_column(String(200))
    popularity: Mapped[int] = mapped_column(default=0, server_default=text("0"))
    setup_tips: Mapped[list[str]] = mapped_column(default=list, server_default=text("'[]'::jsonb"))
    # Incremented on every change so clients can cache a profile.
    version: Mapped[int] = mapped_column(default=1)
