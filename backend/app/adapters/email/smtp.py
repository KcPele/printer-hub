"""Email through any SMTP server (a provider such as Resend or Mailgun, or your own)."""

import smtplib
import ssl
from email.message import EmailMessage as MimeMessage
from typing import Literal

from anyio import to_thread

from app.adapters.email.base import EmailMessage

_TIMEOUT_SECONDS = 15


class SmtpEmailSender:
    def __init__(
        self,
        *,
        host: str,
        port: int,
        sender: str,
        username: str | None = None,
        password: str | None = None,
        security: Literal["starttls", "ssl", "none"] = "starttls",
    ) -> None:
        self._host = host
        self._port = port
        self._sender = sender
        self._username = username
        self._password = password
        self._security = security

    def _deliver(self, message: EmailMessage) -> None:
        mime = MimeMessage()
        mime["From"] = self._sender
        mime["To"] = message.to
        mime["Subject"] = message.subject
        mime.set_content(message.text)

        context = ssl.create_default_context()
        connection: smtplib.SMTP
        if self._security == "ssl":
            connection = smtplib.SMTP_SSL(
                self._host, self._port, timeout=_TIMEOUT_SECONDS, context=context
            )
        else:
            connection = smtplib.SMTP(self._host, self._port, timeout=_TIMEOUT_SECONDS)
        with connection:
            if self._security == "starttls":
                connection.starttls(context=context)
            if self._username and self._password:
                connection.login(self._username, self._password)
            connection.send_message(mime)

    async def send(self, message: EmailMessage) -> None:
        # smtplib blocks; keep it off the event loop.
        await to_thread.run_sync(self._deliver, message)
