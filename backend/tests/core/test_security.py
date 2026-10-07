import uuid
from datetime import UTC, datetime, timedelta

import jwt
import pytest

from app.core.config import get_settings
from app.core.errors import UnauthorizedError
from app.core.security import (
    create_access_token,
    decode_access_token,
    generate_token,
    hash_password,
    hash_token,
    verify_password,
)


def test_password_hash_round_trip() -> None:
    password_hash = hash_password("correct horse battery")

    assert password_hash != "correct horse battery"
    assert verify_password("correct horse battery", password_hash)
    assert not verify_password("wrong", password_hash)


def test_verify_password_rejects_malformed_hash() -> None:
    assert not verify_password("anything", "not-a-hash")


def test_access_token_round_trip() -> None:
    user_id, session_id = uuid.uuid4(), uuid.uuid4()

    token, ttl = create_access_token(user_id, session_id)
    claims = decode_access_token(token)

    assert claims.user_id == user_id
    assert claims.session_id == session_id
    assert ttl == get_settings().access_token_ttl_seconds


def test_expired_access_token_is_rejected() -> None:
    expired = jwt.encode(
        {
            "iss": "printerhub",
            "sub": str(uuid.uuid4()),
            "sid": str(uuid.uuid4()),
            "exp": datetime.now(UTC) - timedelta(seconds=1),
        },
        get_settings().secret_key.get_secret_value(),
        algorithm="HS256",
    )

    with pytest.raises(UnauthorizedError) as error:
        decode_access_token(expired)

    assert error.value.code == "auth.token_expired"


def test_token_signed_with_another_key_is_rejected() -> None:
    forged = jwt.encode(
        {
            "iss": "printerhub",
            "sub": str(uuid.uuid4()),
            "sid": str(uuid.uuid4()),
            "exp": datetime.now(UTC) + timedelta(minutes=5),
        },
        "some-other-key-that-is-long-enough-for-hs256",
        algorithm="HS256",
    )

    with pytest.raises(UnauthorizedError) as error:
        decode_access_token(forged)

    assert error.value.code == "auth.token_invalid"


def test_opaque_tokens_are_unique_and_hash_deterministically() -> None:
    first, second = generate_token(), generate_token()

    assert first != second
    assert hash_token(first) == hash_token(first)
    assert hash_token(first) != hash_token(second)
    assert first not in hash_token(first)
