import json
from urllib.parse import parse_qs

import httpx
import jwt
import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

from app.adapters.push.base import PushMessage, PushOutcome
from app.adapters.push.fcm import FcmPushProvider

MESSAGE = PushMessage(
    title="Print complete", body="Invoice.pdf was printed.", data={"type": "job.completed"}
)
TOKEN_URI = "https://oauth2.example.test/token"


@pytest.fixture(scope="module")
def key_pair() -> tuple[str, str]:
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    private_pem = private_key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    ).decode()
    public_pem = (
        private_key.public_key()
        .public_bytes(serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo)
        .decode()
    )
    return private_pem, public_pem


class FakeGoogle:
    """Stands in for Google's token endpoint and the FCM send endpoint."""

    def __init__(self, send_responses: list[httpx.Response] | None = None) -> None:
        self.token_requests: list[httpx.Request] = []
        self.send_requests: list[httpx.Request] = []
        self._send_responses = send_responses or []

    def __call__(self, request: httpx.Request) -> httpx.Response:
        if str(request.url) == TOKEN_URI:
            self.token_requests.append(request)
            return httpx.Response(
                200,
                json={
                    "access_token": f"access-{len(self.token_requests)}",
                    "expires_in": 3600,
                },
            )
        self.send_requests.append(request)
        if self._send_responses:
            return self._send_responses.pop(0)
        return httpx.Response(200, json={"name": "projects/demo/messages/1"})


def _provider(key_pair: tuple[str, str], google: FakeGoogle) -> FcmPushProvider:
    return FcmPushProvider(
        {
            "project_id": "demo-project",
            "client_email": "push@demo-project.iam.gserviceaccount.com",
            "private_key": key_pair[0],
            "token_uri": TOKEN_URI,
        },
        client=httpx.AsyncClient(transport=httpx.MockTransport(google)),
    )


def _fcm_error(
    status: int, error_status: str, code: str | None = None, message: str = ""
) -> httpx.Response:
    details = [{"@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError", "errorCode": code}]
    return httpx.Response(
        status,
        json={
            "error": {
                "code": status,
                "status": error_status,
                "message": message,
                "details": details if code else [],
            }
        },
    )


async def test_send_authenticates_and_posts_the_message(key_pair: tuple[str, str]) -> None:
    google = FakeGoogle()
    provider = _provider(key_pair, google)

    outcome = await provider.send("device-token-1", MESSAGE)

    assert outcome is PushOutcome.DELIVERED
    # The service-account assertion is signed with the private key and scoped to FCM.
    form = parse_qs(google.token_requests[0].content.decode())
    assert form["grant_type"] == ["urn:ietf:params:oauth:grant-type:jwt-bearer"]
    claims = jwt.decode(form["assertion"][0], key_pair[1], algorithms=["RS256"], audience=TOKEN_URI)
    assert claims["iss"] == "push@demo-project.iam.gserviceaccount.com"
    assert claims["scope"] == "https://www.googleapis.com/auth/firebase.messaging"

    [request] = google.send_requests
    assert str(request.url) == "https://fcm.googleapis.com/v1/projects/demo-project/messages:send"
    assert request.headers["Authorization"] == "Bearer access-1"
    assert json.loads(request.content)["message"] == {
        "token": "device-token-1",
        "notification": {"title": "Print complete", "body": "Invoice.pdf was printed."},
        "data": {"type": "job.completed"},
        "android": {"priority": "HIGH"},
        "apns": {"payload": {"aps": {"sound": "default"}}},
    }


async def test_access_token_is_reused(key_pair: tuple[str, str]) -> None:
    google = FakeGoogle()
    provider = _provider(key_pair, google)

    await provider.send("a", MESSAGE)
    await provider.send("b", MESSAGE)

    assert len(google.token_requests) == 1
    assert len(google.send_requests) == 2


async def test_rejected_access_token_is_refreshed_once(key_pair: tuple[str, str]) -> None:
    google = FakeGoogle([httpx.Response(401, json={"error": {"status": "UNAUTHENTICATED"}})])
    provider = _provider(key_pair, google)

    outcome = await provider.send("a", MESSAGE)

    assert outcome is PushOutcome.DELIVERED
    assert len(google.token_requests) == 2
    assert google.send_requests[1].headers["Authorization"] == "Bearer access-2"


@pytest.mark.parametrize(
    ("response", "expected"),
    [
        (_fcm_error(404, "NOT_FOUND", "UNREGISTERED"), PushOutcome.INVALID_TOKEN),
        (
            _fcm_error(
                400,
                "INVALID_ARGUMENT",
                "INVALID_ARGUMENT",
                "The registration token is not a valid FCM registration token",
            ),
            PushOutcome.INVALID_TOKEN,
        ),
        # A payload mistake is our bug, not a dead device: keep the token.
        (
            _fcm_error(
                400, "INVALID_ARGUMENT", "INVALID_ARGUMENT", "Invalid value at 'message.data'"
            ),
            PushOutcome.FAILED,
        ),
        (_fcm_error(429, "RESOURCE_EXHAUSTED", "QUOTA_EXCEEDED"), PushOutcome.FAILED),
        (_fcm_error(503, "UNAVAILABLE", "UNAVAILABLE"), PushOutcome.FAILED),
        (httpx.Response(502, text="Bad Gateway"), PushOutcome.FAILED),
    ],
)
async def test_error_mapping(
    key_pair: tuple[str, str], response: httpx.Response, expected: PushOutcome
) -> None:
    provider = _provider(key_pair, FakeGoogle([response]))

    assert await provider.send("a", MESSAGE) is expected


async def test_network_failure_is_temporary(key_pair: tuple[str, str]) -> None:
    def unreachable(_: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("no route to host")

    provider = FcmPushProvider(
        {
            "project_id": "demo-project",
            "client_email": "push@demo-project.iam.gserviceaccount.com",
            "private_key": key_pair[0],
            "token_uri": TOKEN_URI,
        },
        client=httpx.AsyncClient(transport=httpx.MockTransport(unreachable)),
    )

    assert await provider.send("a", MESSAGE) is PushOutcome.FAILED
