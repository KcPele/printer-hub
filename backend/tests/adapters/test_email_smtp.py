import smtplib
from email.message import EmailMessage as MimeMessage
from typing import Any

import pytest

from app.adapters.email.base import EmailMessage
from app.adapters.email.smtp import SmtpEmailSender

MESSAGE = EmailMessage(
    to="ada@example.com", subject="Your PrinterHub password reset code", text="Code: 042817"
)


class FakeServer:
    """Records what `SmtpEmailSender` does with an SMTP connection."""

    instances: list[FakeServer] = []

    def __init__(self, host: str, port: int, **kwargs: Any) -> None:
        self.host, self.port, self.kwargs = host, port, kwargs
        self.calls: list[str] = []
        self.sent: list[MimeMessage] = []
        FakeServer.instances.append(self)

    def __enter__(self) -> FakeServer:
        return self

    def __exit__(self, *_: object) -> None:
        self.calls.append("quit")

    def starttls(self, **_: Any) -> None:
        self.calls.append("starttls")

    def login(self, username: str, password: str) -> None:
        self.calls.append(f"login:{username}")

    def send_message(self, message: MimeMessage) -> None:
        self.calls.append("send")
        self.sent.append(message)


@pytest.fixture(autouse=True)
def fake_smtp(monkeypatch: pytest.MonkeyPatch) -> type[FakeServer]:
    FakeServer.instances = []
    monkeypatch.setattr(smtplib, "SMTP", FakeServer)
    monkeypatch.setattr(smtplib, "SMTP_SSL", FakeServer)
    return FakeServer


async def test_starttls_login_then_send(fake_smtp: type[FakeServer]) -> None:
    sender = SmtpEmailSender(
        host="smtp.example.com",
        port=587,
        sender="PrinterHub <no-reply@example.com>",
        username="apikey",
        password="s3cret",
    )

    await sender.send(MESSAGE)

    [server] = fake_smtp.instances
    assert (server.host, server.port) == ("smtp.example.com", 587)
    # Credentials are only ever sent after the connection is encrypted.
    assert server.calls == ["starttls", "login:apikey", "send", "quit"]
    [mime] = server.sent
    assert mime["From"] == "PrinterHub <no-reply@example.com>"
    assert mime["To"] == "ada@example.com"
    assert mime["Subject"] == "Your PrinterHub password reset code"
    assert mime.get_content().strip() == "Code: 042817"


async def test_implicit_tls_skips_starttls(fake_smtp: type[FakeServer]) -> None:
    sender = SmtpEmailSender(
        host="smtp.example.com",
        port=465,
        sender="no-reply@example.com",
        username="u",
        password="p",
        security="ssl",
    )

    await sender.send(MESSAGE)

    assert fake_smtp.instances[0].calls == ["login:u", "send", "quit"]
    assert "context" in fake_smtp.instances[0].kwargs


async def test_no_login_without_credentials(fake_smtp: type[FakeServer]) -> None:
    sender = SmtpEmailSender(
        host="localhost", port=25, sender="no-reply@example.com", security="none"
    )

    await sender.send(MESSAGE)

    assert fake_smtp.instances[0].calls == ["send", "quit"]


async def test_failure_propagates_so_the_worker_can_retry(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def refuse(*_: Any, **__: Any) -> None:
        raise smtplib.SMTPConnectError(421, "Service not available")

    monkeypatch.setattr(smtplib, "SMTP", refuse)
    sender = SmtpEmailSender(host="smtp.example.com", port=587, sender="no-reply@example.com")

    with pytest.raises(smtplib.SMTPConnectError):
        await sender.send(MESSAGE)


async def test_an_email_with_html_carries_its_text_too(fake_smtp: type[FakeServer]) -> None:
    sender = SmtpEmailSender(host="smtp.example.com", port=587, sender="PrinterHub <a@example.com>")

    await sender.send(
        EmailMessage(
            to="ada@example.com",
            subject="Verify your PrinterHub email address",
            text="Code: 042817",
            html="<p>Code: <b>042817</b></p>",
        )
    )

    [mime] = fake_smtp.instances[0].sent
    assert mime.get_content_type() == "multipart/alternative"
    # Text first, HTML last: a mail client shows the last form it can.
    text, html = mime.iter_parts()
    assert text.get_content_type() == "text/plain"
    assert text.get_content().strip() == "Code: 042817"
    assert html.get_content_type() == "text/html"
    assert "<b>042817</b>" in html.get_content()
