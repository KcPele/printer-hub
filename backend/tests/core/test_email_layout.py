import re

from app.core import email_layout
from app.modules.auth import emails


def _render(**changes: object) -> str:
    given: dict[str, object] = {
        "preview": "Enter it in the app.",
        "heading": "Confirm your email address",
        "before": ["Hi Ada,", "Your code is:"],
        "code": "042817",
        "after": ["Enter it in the app."],
        "footnote": "If this was not you, ignore this email.",
    }
    return email_layout.render(**{**given, **changes})  # type: ignore[arg-type]


def test_an_email_says_everything_it_was_given() -> None:
    html = _render()

    assert html.startswith("<!doctype html>")
    assert "<h1" in html
    assert "Confirm your email address" in html
    for words in ("Hi Ada,", "Your code is:", "042817", "Enter it in the app."):
        assert words in html
    assert "If this was not you, ignore this email." in html
    assert "PrinterHub" in html


def test_what_is_given_is_escaped() -> None:
    html = _render(before=["Hi <script>alert(1)</script> & co,"], heading='A "quoted" <b>')

    assert "<script>" not in html
    assert "&lt;script&gt;alert(1)&lt;/script&gt; &amp; co," in html
    assert "<b>" not in html


def test_the_inbox_preview_never_holds_the_code() -> None:
    html = _render()

    hidden = re.search(r'<div style="display:none[^"]*">(.*?)</div>', html)
    assert hidden is not None
    assert hidden.group(1) == "Enter it in the app."
    assert "042817" not in hidden.group(1)


def test_an_email_loads_nothing_from_anywhere() -> None:
    # No picture, font, or stylesheet to fetch: it looks finished with images
    # switched off, and opening it tells nobody that it was opened.
    html = _render()

    assert "<img" not in html
    assert "http" not in html
    assert "<link" not in html
    assert "<script" not in html


def test_the_code_and_the_rest_are_optional() -> None:
    html = _render(code=None, after=None, footnote=None)

    assert "letter-spacing:8px" not in html
    assert "border-top" not in html
    assert "Your code is:" in html


def test_the_auth_emails_say_the_same_in_text_and_in_html() -> None:
    for message in (
        emails.verification("ada@example.com", "Ada", "042817"),
        emails.password_reset("ada@example.com", "Ada", "042817"),
    ):
        assert message.html is not None
        # Every line of the text is in the HTML too.
        for line in message.text.splitlines():
            if line.strip():
                assert line.strip() in message.html
