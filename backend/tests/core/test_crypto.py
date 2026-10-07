import pytest
from cryptography.fernet import InvalidToken

from app.core.crypto import decrypt_json, encrypt_json


def test_round_trip() -> None:
    secret = {"username": "scanner", "password": "hunter2"}

    blob = encrypt_json(secret)

    assert b"hunter2" not in blob
    assert decrypt_json(blob) == secret


def test_tampered_ciphertext_is_rejected() -> None:
    blob = bytearray(encrypt_json({"password": "hunter2"}))
    blob[-1] ^= 0x01

    with pytest.raises(InvalidToken):
        decrypt_json(bytes(blob))
