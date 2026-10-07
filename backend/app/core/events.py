"""Live events for connected clients.

An event is deliberately thin: a type, the IDs involved, and the new status.
Clients refetch the full record through the REST API, which keeps
authorization in one place. The channel decides who can see an event.
"""

import uuid
from collections.abc import Sequence
from datetime import UTC, datetime
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.adapters.realtime import get_realtime_publisher
from app.core.db import after_commit
from app.core.ids import new_id


def org_channel(organization_id: uuid.UUID) -> str:
    """Printer and connection events. Any member who can read printers may subscribe."""
    return f"private-org-{organization_id}"


def org_jobs_channel(organization_id: uuid.UUID) -> str:
    """Every job event in the organization. Requires `jobs.read_all`."""
    return f"private-org-{organization_id}-jobs"


def user_channel(user_id: uuid.UUID) -> str:
    """A user's own job events and notifications."""
    return f"private-user-{user_id}"


def emit(session: AsyncSession, channels: Sequence[str], type: str, data: dict[str, Any]) -> None:
    """Publish `type` to `channels` once the session's transaction commits."""
    payload = {
        "event_id": str(new_id()),
        "occurred_at": datetime.now(UTC).isoformat(),
        **data,
    }
    targets = tuple(dict.fromkeys(channels))

    async def publish() -> None:
        await get_realtime_publisher().publish(targets, type, payload)

    after_commit(session, publish)
