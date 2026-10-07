import uuid

from sqlalchemy import ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, IdMixin, TimestampMixin


class FeatureFlag(Base, TimestampMixin):
    """A switch for a client or backend capability (FRD §55.1 item 18)."""

    __tablename__ = "feature_flags"

    key: Mapped[str] = mapped_column(String(100), primary_key=True)
    description: Mapped[str] = mapped_column(String(500), default="")
    # The value for every organization without an override.
    enabled: Mapped[bool] = mapped_column(default=False)


class FeatureFlagOverride(Base, IdMixin, TimestampMixin):
    __tablename__ = "feature_flag_overrides"
    __table_args__ = (UniqueConstraint("flag_key", "organization_id"),)

    flag_key: Mapped[str] = mapped_column(ForeignKey("feature_flags.key", ondelete="CASCADE"))
    organization_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("organizations.id", ondelete="CASCADE"), index=True
    )
    enabled: Mapped[bool]
