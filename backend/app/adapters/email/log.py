import structlog

from app.adapters.email.base import EmailMessage

log = structlog.get_logger(__name__)


class LogEmailSender:
    """Writes emails to the log. The default until SMTP is configured.

    The body is logged in full, one-time codes included, so that sign-up can
    be exercised without a mail server. Configure SMTP before real users arrive.
    """

    async def send(self, message: EmailMessage) -> None:
        log.info("email_logged", to=message.to, subject=message.subject, text=message.text)
