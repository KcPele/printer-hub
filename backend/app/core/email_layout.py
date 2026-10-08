"""The look every PrinterHub email shares: the Mint theme, as HTML a mail client can draw.

Mail clients draw old HTML: tables for layout, styles on each element, no
web fonts, and no pictures unless the reader allows them. So the layout is
tables, the type is whatever the reader's device has, and nothing is a
picture: the email looks finished with images switched off.

An email always goes out with its plain text too. This is how it looks where
HTML is shown; the text is what a reader sees where it is not.
"""

from html import escape

# The Mint theme, as `docs/mobile-app-implementation.md` section 4 has it.
_PRIMARY = "#46D7B7"
_ON_PRIMARY = "#0B3B32"
_TINT = "#E9FAF6"
_TEXT = "#1A1A1A"
_MUTED = "#5E6366"
_PAGE = "#F4F5F5"
_CARD = "#FFFFFF"
_LINE = "#E5E7E8"
_SANS = "-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif"
_MONO = "ui-monospace,SFMono-Regular,Menlo,Consolas,'Liberation Mono',monospace"

_TAGLINE = "Print, scan and copy from your phone."


def _paragraph(text: str, *, color: str = _TEXT, size: int = 16) -> str:
    return (
        f'<p style="margin:0 0 16px;font-family:{_SANS};font-size:{size}px;'
        f'line-height:1.5;color:{color};">{escape(text)}</p>'
    )


def _code(code: str) -> str:
    """A one-time code, set large and spaced so it can be read off and typed."""
    return (
        '<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" '
        'style="margin:8px 0 24px;"><tr>'
        f'<td align="center" style="background:{_TINT};border-radius:12px;padding:20px 16px;'
        f"font-family:{_MONO};font-size:32px;line-height:1.2;font-weight:700;"
        f'letter-spacing:8px;color:{_ON_PRIMARY};">{escape(code)}</td>'
        "</tr></table>"
    )


def render(
    *,
    preview: str,
    heading: str,
    before: list[str],
    code: str | None = None,
    after: list[str] | None = None,
    footnote: str | None = None,
) -> str:
    """One email: a heading, what it is about, a code when there is one, and what to do.

    `preview` is the line an inbox shows beside the subject. It never holds
    the code: an inbox preview can be read over a shoulder or on a lock screen.
    Everything given is escaped, so a name with markup in it stays a name.
    """
    body = "".join(_paragraph(text) for text in before)
    if code is not None:
        body += _code(code)
    body += "".join(_paragraph(text) for text in after or [])
    if footnote is not None:
        body += (
            f'<p style="margin:8px 0 0;padding-top:16px;border-top:1px solid {_LINE};'
            f'font-family:{_SANS};font-size:13px;line-height:1.5;color:{_MUTED};">'
            f"{escape(footnote)}</p>"
        )

    return (
        "<!doctype html>"
        '<html lang="en"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        '<meta name="color-scheme" content="light">'
        f"<title>{escape(heading)}</title></head>"
        f'<body style="margin:0;padding:0;background:{_PAGE};">'
        # Shown in the inbox beside the subject, and nowhere in the email.
        '<div style="display:none;max-height:0;overflow:hidden;opacity:0;">'
        f"{escape(preview)}</div>"
        '<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" '
        f'style="background:{_PAGE};"><tr><td align="center" style="padding:32px 16px;">'
        '<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" '
        f'style="max-width:480px;background:{_CARD};border:1px solid {_LINE};'
        'border-radius:14px;overflow:hidden;">'
        # The band of the theme's colour, and the name.
        f'<tr><td style="background:{_PRIMARY};height:6px;line-height:6px;font-size:0;">'
        "&nbsp;</td></tr>"
        f'<tr><td style="padding:28px 32px 0;font-family:{_SANS};font-size:20px;'
        f'font-weight:800;letter-spacing:-0.02em;color:{_TEXT};">PrinterHub</td></tr>'
        f'<tr><td style="padding:20px 32px 32px;">'
        f'<h1 style="margin:0 0 16px;font-family:{_SANS};font-size:24px;line-height:1.25;'
        f'font-weight:800;letter-spacing:-0.02em;color:{_TEXT};">{escape(heading)}</h1>'
        f"{body}</td></tr></table>"
        f'<p style="margin:16px 0 0;font-family:{_SANS};font-size:12px;line-height:1.5;'
        f'color:{_MUTED};">PrinterHub · {_TAGLINE}</p>'
        "</td></tr></table></body></html>"
    )
