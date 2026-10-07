from dataclasses import dataclass, field

from app.adapters.email.base import EmailMessage


@dataclass
class MemoryEmailSender:
    """Records emails. Used by tests."""

    sent: list[EmailMessage] = field(default_factory=list)
    # Set to make `send` fail, to exercise retry.
    failure: Exception | None = None

    async def send(self, message: EmailMessage) -> None:
        if self.failure is not None:
            raise self.failure
        self.sent.append(message)

    def reset(self) -> None:
        self.sent.clear()
        self.failure = None
