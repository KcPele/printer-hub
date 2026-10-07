"""Text of the emails the auth flows send."""

from app.adapters.email.base import EmailMessage
from app.core.config import get_settings


def _expiry() -> str:
    return f"{get_settings().email_code_ttl_minutes} minutes"


def verification(to: str, name: str, code: str) -> EmailMessage:
    return EmailMessage(
        to=to,
        subject="Verify your PrinterHub email address",
        text=(
            f"Hi {name},\n\n"
            f"Your PrinterHub verification code is:\n\n    {code}\n\n"
            f"Enter it in the app to confirm this email address. It expires in {_expiry()}.\n\n"
            "If you did not create a PrinterHub account, you can ignore this email.\n"
        ),
    )


def password_reset(to: str, name: str, code: str) -> EmailMessage:
    return EmailMessage(
        to=to,
        subject="Your PrinterHub password reset code",
        text=(
            f"Hi {name},\n\n"
            f"Your PrinterHub password reset code is:\n\n    {code}\n\n"
            f"Enter it in the app to choose a new password. It expires in {_expiry()}.\n\n"
            "If you did not ask to reset your password, you can ignore this email. "
            "Your password has not changed.\n"
        ),
    )
