"""Password hashing and token primitives."""

import hashlib
import secrets
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError

from app.core.config import get_settings
from app.core.errors import UnauthorizedError

_ALGORITHM = "HS256"
_ISSUER = "printerhub"
_password_hasher = PasswordHasher()


@dataclass(frozen=True, slots=True)
class AccessClaims:
    user_id: uuid.UUID
    session_id: uuid.UUID


def hash_password(password: str) -> str:
    """Hash with Argon2id. CPU-bound: call through a thread from async code."""
    return _password_hasher.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    """CPU-bound: call through a thread from async code."""
    try:
        return _password_hasher.verify(password_hash, password)
    except VerificationError, InvalidHashError:
        return False


def create_access_token(user_id: uuid.UUID, session_id: uuid.UUID) -> tuple[str, int]:
    """Return a signed access token and its lifetime in seconds."""
    settings = get_settings()
    now = datetime.now(UTC)
    ttl = settings.access_token_ttl_seconds
    payload = {
        "iss": _ISSUER,
        "sub": str(user_id),
        "sid": str(session_id),
        "iat": now,
        "exp": now + timedelta(seconds=ttl),
    }
    token = jwt.encode(payload, settings.secret_key.get_secret_value(), algorithm=_ALGORITHM)
    return token, ttl


def decode_access_token(token: str) -> AccessClaims:
    settings = get_settings()
    try:
        payload = jwt.decode(
            token,
            settings.secret_key.get_secret_value(),
            algorithms=[_ALGORITHM],
            issuer=_ISSUER,
            options={"require": ["exp", "sub", "sid"]},
        )
        return AccessClaims(
            user_id=uuid.UUID(payload["sub"]),
            session_id=uuid.UUID(payload["sid"]),
        )
    except jwt.ExpiredSignatureError as exc:
        raise UnauthorizedError("auth.token_expired", "The access token has expired.") from exc
    except (jwt.InvalidTokenError, ValueError) as exc:
        raise UnauthorizedError("auth.token_invalid", "The access token is not valid.") from exc


def generate_token() -> str:
    """Return a URL-safe opaque token with 256 bits of entropy."""
    return secrets.token_urlsafe(32)


def hash_token(token: str) -> str:
    """Hash an opaque token for storage.

    SHA-256 without salt is sufficient: the input is 256 random bits, so it
    cannot be guessed or precomputed, and a deterministic hash allows lookup.
    """
    return hashlib.sha256(token.encode()).hexdigest()
