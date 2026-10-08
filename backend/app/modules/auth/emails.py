"""The emails the auth flows send: their words once, as plain text and as HTML."""

from app.adapters.email.base import EmailMessage
from app.core import email_layout
from app.core.config import get_settings


def _expiry() -> str:
    return f"{get_settings().email_code_ttl_minutes} minutes"


def _code_email(
    *,
    to: str,
    name: str,
    code: str,
    subject: str,
    heading: str,
    lead: str,
    instruction: str,
    otherwise: str,
) -> EmailMessage:
    """An email that carries a one-time code, saying the same in text and in HTML."""
    greeting = f"Hi {name},"
    return EmailMessage(
        to=to,
        subject=subject,
        text=f"{greeting}\n\n{lead}\n\n    {code}\n\n{instruction}\n\n{otherwise}\n",
        html=email_layout.render(
            preview=instruction,
            heading=heading,
            before=[greeting, lead],
            code=code,
            after=[instruction],
            footnote=otherwise,
        ),
    )


def verification(to: str, name: str, code: str) -> EmailMessage:
    return _code_email(
        to=to,
        name=name,
        code=code,
        subject="Verify your PrinterHub email address",
        heading="Confirm your email address",
        lead="Your PrinterHub verification code is:",
        instruction=(
            f"Enter it in the app to confirm this email address. It expires in {_expiry()}."
        ),
        otherwise="If you did not create a PrinterHub account, you can ignore this email.",
    )


def password_reset(to: str, name: str, code: str) -> EmailMessage:
    return _code_email(
        to=to,
        name=name,
        code=code,
        subject="Your PrinterHub password reset code",
        heading="Reset your password",
        lead="Your PrinterHub password reset code is:",
        instruction=f"Enter it in the app to choose a new password. It expires in {_expiry()}.",
        otherwise=(
            "If you did not ask to reset your password, you can ignore this email. "
            "Your password has not changed."
        ),
    )
