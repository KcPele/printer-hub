from dataclasses import dataclass
from typing import Protocol


@dataclass(frozen=True, slots=True)
class EmailMessage:
    to: str
    subject: str
    text: str
    # How the email looks where HTML is shown. The text always goes with it,
    # for the readers and mail clients that show text only.
    html: str | None = None


class EmailSender(Protocol):
    async def send(self, message: EmailMessage) -> None:
        """Deliver `message`, or raise so the caller can try again."""
        ...
