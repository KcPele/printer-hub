from collections.abc import Sequence
from typing import Any


class NullPublisher:
    """Drops events. Used when live WebSocket updates are turned off."""

    async def publish(self, channels: Sequence[str], event: str, data: dict[str, Any]) -> None:
        return None
