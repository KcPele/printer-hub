import uuid

from app.core.ids import new_id
from app.core.pagination import decode_cursor, encode_cursor


def test_ids_are_version_7_and_sort_by_creation() -> None:
    ids = [new_id() for _ in range(100)]

    assert all(value.version == 7 for value in ids)
    assert ids == sorted(ids)


def test_cursor_round_trip() -> None:
    value = uuid.uuid4()

    assert decode_cursor(encode_cursor(value)) == value
