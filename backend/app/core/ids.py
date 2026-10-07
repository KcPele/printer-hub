"""Identifier generation."""

import uuid


def new_id() -> uuid.UUID:
    """Return a UUIDv7. Its leading bits are a timestamp, so IDs sort by creation time."""
    return uuid.uuid7()
