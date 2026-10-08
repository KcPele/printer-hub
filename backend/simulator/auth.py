"""HTTP sign-in for the simulated printer: Basic and Digest (RFC 7617, RFC 7616)."""

import base64
import hashlib
import re

from simulator.state import PrinterState

REALM = "PrinterHub simulator"
_PARAMETER = re.compile(r'(\w+)=(?:"([^"]*)"|([^,\s]+))')


def challenge(printer: PrinterState) -> str:
    """The `WWW-Authenticate` header the printer answers an unsigned request with."""
    if printer.auth == "basic":
        return f'Basic realm="{REALM}"'
    return f'Digest realm="{REALM}", nonce="{printer.auth_nonce}", qop="auth", algorithm=MD5'


def _md5(text: str) -> str:
    return hashlib.md5(text.encode(), usedforsecurity=False).hexdigest()


def authorized(printer: PrinterState, header: str | None, method: str, path: str) -> bool:
    """Whether `header` signs the request in as the printer's user."""
    if printer.auth == "none":
        return True
    if header is None:
        return False
    scheme, _, rest = header.partition(" ")
    if printer.auth == "basic":
        expected = base64.b64encode(f"{printer.auth_user}:{printer.auth_password}".encode())
        return scheme.lower() == "basic" and rest.strip().encode() == expected
    if scheme.lower() != "digest":
        return False
    given = {
        m.group(1): m.group(2) if m.group(2) is not None else m.group(3)
        for m in _PARAMETER.finditer(rest)
    }
    if given.get("username") != printer.auth_user or given.get("nonce") != printer.auth_nonce:
        return False
    if given.get("uri") != path:
        return False
    user = _md5(f"{printer.auth_user}:{REALM}:{printer.auth_password}")
    request = _md5(f"{method}:{path}")
    signed = _md5(
        f"{user}:{printer.auth_nonce}:{given.get('nc')}:{given.get('cnonce')}:auth:{request}"
    )
    return given.get("response") == signed
