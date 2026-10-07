from app.core.logging import REDACTED, redact_sensitive


def test_redacts_sensitive_keys_at_any_depth() -> None:
    event = {
        "event": "connection_saved",
        "password": "hunter2",
        "headers": {"Authorization": "Bearer abc", "accept": "application/json"},
        "items": [{"refresh_token": "xyz", "name": "Office"}],
        "secure_print_pin": "1234",
    }

    result = redact_sensitive(None, "info", event)

    assert result["password"] == REDACTED
    assert result["headers"] == {"Authorization": REDACTED, "accept": "application/json"}
    assert result["items"] == [{"refresh_token": REDACTED, "name": "Office"}]
    assert result["secure_print_pin"] == REDACTED
    assert result["event"] == "connection_saved"
