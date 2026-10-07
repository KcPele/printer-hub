"""Symmetric encryption for secrets stored in the database (FR-SEC-003)."""

import json
from functools import lru_cache
from typing import Any

from cryptography.fernet import Fernet

from app.core.config import get_settings


@lru_cache
def _fernet() -> Fernet:
    return Fernet(get_settings().credentials_encryption_key.get_secret_value())


def encrypt_json(data: dict[str, Any]) -> bytes:
    return _fernet().encrypt(json.dumps(data, separators=(",", ":")).encode())


def decrypt_json(blob: bytes) -> dict[str, Any]:
    decoded: dict[str, Any] = json.loads(_fernet().decrypt(blob))
    return decoded
