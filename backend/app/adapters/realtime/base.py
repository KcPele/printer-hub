from collections.abc import Sequence
from typing import Any, Protocol


class RealtimePublisher(Protocol):
    """Delivers live events to connected clients."""

    async def publish(self, channels: Sequence[str], event: str, data: dict[str, Any]) -> None:
        """Send `event` with `data` to every channel in `channels`."""
        ...
