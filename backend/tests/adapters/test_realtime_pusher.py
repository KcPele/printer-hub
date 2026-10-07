import hashlib
import hmac
import json
from urllib.parse import parse_qsl

import httpx
import pytest

from app.adapters.realtime.pusher import (
    PusherPublisher,
    RealtimePublishError,
    sign_channel_auth,
    sign_request,
)


def test_channel_auth_matches_the_pusher_reference_vector() -> None:
    # From the Pusher docs, "Worked example" for private channel authorization.
    auth = sign_channel_auth(
        "278d425bdf160c739803",
        "7ad3773142a6692b25b8",
        "1234.1234",
        "private-foobar",
    )

    assert auth == (
        "278d425bdf160c739803:58df8b0c36d6982b82c3ecf6b4662e34fe8c25bba48f5369f135bf843651c3a4"
    )


def test_request_signature_matches_the_pusher_reference_vector() -> None:
    # From the Pusher docs, "Worked authentication example" for the HTTP API.
    params = {
        "auth_key": "278d425bdf160c739803",
        "auth_timestamp": "1353088179",
        "auth_version": "1.0",
        "body_md5": "ec365a775a4cd0599faeb73354201b6f",
    }

    signature = sign_request("7ad3773142a6692b25b8", "POST", "/apps/3/events", params)

    assert signature == "da454824c97ba181a32ccc17a72625ba02771f50b50e1e7430e47a1f3f457e6c"


async def test_publish_sends_a_signed_request() -> None:
    captured: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        captured.append(request)
        return httpx.Response(200, json={})

    publisher = PusherPublisher(
        base_url="http://soketi:6001/",
        app_id="app-1",
        key="key-1",
        secret="secret-1",
        client=httpx.AsyncClient(transport=httpx.MockTransport(handler)),
    )

    await publisher.publish(["private-org-1", "private-user-2"], "job.updated", {"job_id": "j1"})

    [request] = captured
    assert request.method == "POST"
    assert request.url.path == "/apps/app-1/events"
    body = json.loads(request.content)
    assert body["name"] == "job.updated"
    assert body["channels"] == ["private-org-1", "private-user-2"]
    assert json.loads(body["data"]) == {"job_id": "j1"}

    params = dict(parse_qsl(request.url.query.decode()))
    assert params["auth_key"] == "key-1"
    assert params["body_md5"] == hashlib.md5(request.content, usedforsecurity=False).hexdigest()
    signature = params.pop("auth_signature")
    query = "&".join(f"{key}={params[key]}" for key in sorted(params))
    expected = hmac.new(
        b"secret-1", f"POST\n/apps/app-1/events\n{query}".encode(), hashlib.sha256
    ).hexdigest()
    assert signature == expected


async def test_publish_splits_more_than_100_channels() -> None:
    calls: list[int] = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(len(json.loads(request.content)["channels"]))
        return httpx.Response(200, json={})

    publisher = PusherPublisher(
        base_url="http://soketi:6001",
        app_id="a",
        key="k",
        secret="s",
        client=httpx.AsyncClient(transport=httpx.MockTransport(handler)),
    )

    await publisher.publish([f"private-user-{n}" for n in range(150)], "ping", {})

    assert calls == [100, 50]


async def test_rejection_reported_inside_a_200_response_raises() -> None:
    # Soketi answers 200 with an error body when the signature is wrong.
    def handler(_: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"error": "The secret authentication failed", "code": 401})

    publisher = PusherPublisher(
        base_url="http://soketi:6001",
        app_id="a",
        key="k",
        secret="wrong",
        client=httpx.AsyncClient(transport=httpx.MockTransport(handler)),
    )

    with pytest.raises(RealtimePublishError, match="401"):
        await publisher.publish(["private-user-1"], "ping", {})


async def test_http_error_status_raises() -> None:
    publisher = PusherPublisher(
        base_url="http://soketi:6001",
        app_id="a",
        key="k",
        secret="s",
        client=httpx.AsyncClient(transport=httpx.MockTransport(lambda _: httpx.Response(503))),
    )

    with pytest.raises(httpx.HTTPStatusError):
        await publisher.publish(["private-user-1"], "ping", {})
