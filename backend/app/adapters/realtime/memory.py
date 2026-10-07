from collections.abc import Sequence
from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class PublishedEvent:
    channels: tuple[str, ...]
    event: str
    data: dict[str, Any]


@dataclass
class MemoryPublisher:
    """Records events instead of sending them. Used by tests."""

    published: list[PublishedEvent] = field(default_factory=list)

    async def publish(self, channels: Sequence[str], event: str, data: dict[str, Any]) -> None:
        self.published.append(PublishedEvent(tuple(channels), event, data))

    def events(self, event: str) -> list[PublishedEvent]:
        return [item for item in self.published if item.event == event]
