import structlog

from app.adapters.push.base import PushMessage, PushOutcome

log = structlog.get_logger(__name__)


class LogPushProvider:
    """Writes pushes to the log. The default until FCM is configured."""

    async def send(self, token: str, message: PushMessage) -> PushOutcome:
        log.info(
            "push_logged",
            title=message.title,
            body=message.body,
            data=message.data,
            device=token[-6:],
        )
        return PushOutcome.DELIVERED
