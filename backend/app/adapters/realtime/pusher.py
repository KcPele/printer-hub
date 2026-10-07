"""Publisher for Soketi and any other server speaking the Pusher HTTP API.

Protocol reference: https://pusher.com/docs/channels/library_auth_reference/rest-api/
"""

import hashlib
import hmac
import json
import time
from collections.abc import Mapping, Sequence
from typing import Any

import httpx

# The Pusher API accepts at most 100 channels per publish call.
_MAX_CHANNELS_PER_CALL = 100


class RealtimePublishError(Exception):
    """The realtime server refused a publish."""


def sign_request(secret: str, method: str, path: str, params: Mapping[str, str]) -> str:
    """Signature for a Pusher HTTP API request: HMAC-SHA256 over method, path, sorted query."""
    query = "&".join(f"{key}={params[key]}" for key in sorted(params))
    message = f"{method}\n{path}\n{query}"
    return hmac.new(secret.encode(), message.encode(), hashlib.sha256).hexdigest()


def sign_channel_auth(key: str, secret: str, socket_id: str, channel: str) -> str:
    """The `auth` value a client presents to subscribe to a private channel."""
    signature = hmac.new(
        secret.encode(), f"{socket_id}:{channel}".encode(), hashlib.sha256
    ).hexdigest()
    return f"{key}:{signature}"


class PusherPublisher:
    def __init__(
        self,
        *,
        base_url: str,
        app_id: str,
        key: str,
        secret: str,
        client: httpx.AsyncClient | None = None,
    ) -> None:
        self._base_url = base_url.rstrip("/")
        self._app_id = app_id
        self._key = key
        self._secret = secret
        self._client = client or httpx.AsyncClient(timeout=5.0)

    async def publish(self, channels: Sequence[str], event: str, data: dict[str, Any]) -> None:
        for start in range(0, len(channels), _MAX_CHANNELS_PER_CALL):
            await self._publish_batch(channels[start : start + _MAX_CHANNELS_PER_CALL], event, data)

    async def _publish_batch(
        self, channels: Sequence[str], event: str, data: dict[str, Any]
    ) -> None:
        path = f"/apps/{self._app_id}/events"
        body = json.dumps(
            {"name": event, "channels": list(channels), "data": json.dumps(data)},
            separators=(",", ":"),
        ).encode()
        params = {
            "auth_key": self._key,
            "auth_timestamp": str(int(time.time())),
            "auth_version": "1.0",
            # MD5 is mandated by the protocol as a body checksum, not as a security measure.
            "body_md5": hashlib.md5(body, usedforsecurity=False).hexdigest(),
        }
        params["auth_signature"] = sign_request(self._secret, "POST", path, params)
        response = await self._client.post(
            f"{self._base_url}{path}",
            params=params,
            content=body,
            headers={"Content-Type": "application/json"},
        )
        response.raise_for_status()
        _raise_if_rejected(response)


def _raise_if_rejected(response: httpx.Response) -> None:
    """Soketi reports failures such as a bad signature in the body of a 200 response."""
    try:
        body = response.json()
    except ValueError:
        return
    if isinstance(body, dict) and "error" in body:
        raise RealtimePublishError(f"{body.get('code', 'unknown')}: {body['error']}")
