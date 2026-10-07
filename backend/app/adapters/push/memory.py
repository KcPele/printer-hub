from dataclasses import dataclass, field

from app.adapters.push.base import PushMessage, PushOutcome


@dataclass
class MemoryPushProvider:
    """Records pushes. Tests script failures through `outcomes`."""

    sent: list[tuple[str, PushMessage]] = field(default_factory=list)
    # Outcome to return for a given token; anything else is delivered.
    outcomes: dict[str, PushOutcome] = field(default_factory=dict)

    async def send(self, token: str, message: PushMessage) -> PushOutcome:
        outcome = self.outcomes.get(token, PushOutcome.DELIVERED)
        if outcome is PushOutcome.DELIVERED:
            self.sent.append((token, message))
        return outcome

    def reset(self) -> None:
        self.sent.clear()
        self.outcomes.clear()
