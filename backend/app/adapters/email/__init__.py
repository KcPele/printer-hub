from functools import lru_cache

from app.adapters.email.base import EmailSender
from app.adapters.email.log import LogEmailSender
from app.adapters.email.memory import MemoryEmailSender
from app.adapters.email.smtp import SmtpEmailSender
from app.core.config import get_settings


@lru_cache
def get_email_sender() -> EmailSender:
    settings = get_settings()
    if settings.email_backend == "memory":
        return MemoryEmailSender()
    if settings.email_backend == "smtp":
        assert settings.smtp_host is not None  # noqa: S101 - checked by Settings
        return SmtpEmailSender(
            host=settings.smtp_host,
            port=settings.smtp_port,
            sender=settings.email_from,
            username=settings.smtp_username,
            password=(
                settings.smtp_password.get_secret_value() if settings.smtp_password else None
            ),
            security=settings.smtp_security,
        )
    return LogEmailSender()
