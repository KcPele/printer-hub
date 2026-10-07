import enum
from dataclasses import dataclass, field
from typing import Protocol


@dataclass(frozen=True, slots=True)
class PushMessage:
    title: str
    body: str
    # Delivered to the app alongside the visible notification. An open app
    # reads `type` and the IDs here to refresh the affected screen.
    data: dict[str, str] = field(default_factory=dict)


class PushOutcome(enum.StrEnum):
    DELIVERED = "delivered"
    # The token will never work again: remove it from the device.
    INVALID_TOKEN = "invalid_token"  # noqa: S105
    # Temporary problem: worth another attempt.
    FAILED = "failed"


class PushProvider(Protocol):
    async def send(self, token: str, message: PushMessage) -> PushOutcome:
        """Deliver `message` to the device registered under `token`."""
        ...
