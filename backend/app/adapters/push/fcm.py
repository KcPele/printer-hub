"""Firebase Cloud Messaging, HTTP v1 API.

FCM delivers to Android directly and to iOS through APNs, so it is the only
push service the backend talks to.

Reference: https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages
"""

import asyncio
import json
import time
from typing import Any

import httpx
import jwt
import structlog

from app.adapters.push.base import PushMessage, PushOutcome

log = structlog.get_logger(__name__)

_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
_DEFAULT_TOKEN_URI = "https://oauth2.googleapis.com/token"  # noqa: S105
_GRANT_TYPE = "urn:ietf:params:oauth:grant-type:jwt-bearer"
_ASSERTION_LIFETIME_SECONDS = 3600
# Refresh this long before the access token expires.
_EXPIRY_MARGIN_SECONDS = 60


class FcmPushProvider:
    def __init__(
        self,
        service_account: dict[str, Any],
        *,
        client: httpx.AsyncClient | None = None,
    ) -> None:
        self._project_id: str = service_account["project_id"]
        self._client_email: str = service_account["client_email"]
        self._private_key: str = service_account["private_key"]
        self._token_uri: str = service_account.get("token_uri", _DEFAULT_TOKEN_URI)
        self._client = client or httpx.AsyncClient(timeout=10.0)
        self._access_token: str | None = None
        self._access_token_expires_at = 0.0
        self._lock = asyncio.Lock()

    @classmethod
    def from_json(cls, service_account_json: str) -> FcmPushProvider:
        return cls(json.loads(service_account_json))

    async def _get_access_token(self, *, force_refresh: bool = False) -> str:
        async with self._lock:
            now = time.time()
            if (
                not force_refresh
                and self._access_token is not None
                and now < self._access_token_expires_at - _EXPIRY_MARGIN_SECONDS
            ):
                return self._access_token

            issued_at = int(now)
            assertion = jwt.encode(
                {
                    "iss": self._client_email,
                    "scope": _SCOPE,
                    "aud": self._token_uri,
                    "iat": issued_at,
                    "exp": issued_at + _ASSERTION_LIFETIME_SECONDS,
                },
                self._private_key,
                algorithm="RS256",
            )
            response = await self._client.post(
                self._token_uri, data={"grant_type": _GRANT_TYPE, "assertion": assertion}
            )
            response.raise_for_status()
            payload = response.json()
            self._access_token = str(payload["access_token"])
            self._access_token_expires_at = now + float(payload.get("expires_in", 3600))
            return self._access_token

    async def _post(self, token: str, message: PushMessage, access_token: str) -> httpx.Response:
        return await self._client.post(
            f"https://fcm.googleapis.com/v1/projects/{self._project_id}/messages:send",
            headers={"Authorization": f"Bearer {access_token}"},
            json={
                "message": {
                    "token": token,
                    "notification": {"title": message.title, "body": message.body},
                    "data": message.data,
                    "android": {"priority": "HIGH"},
                    "apns": {"payload": {"aps": {"sound": "default"}}},
                }
            },
        )

    async def send(self, token: str, message: PushMessage) -> PushOutcome:
        try:
            response = await self._post(token, message, await self._get_access_token())
            if response.status_code == httpx.codes.UNAUTHORIZED:
                # The cached access token was revoked or expired early.
                response = await self._post(
                    token, message, await self._get_access_token(force_refresh=True)
                )
        except httpx.HTTPError as error:
            log.warning("fcm_request_failed", error=type(error).__name__)
            return PushOutcome.FAILED

        if response.is_success:
            return PushOutcome.DELIVERED
        if _is_invalid_registration(response):
            return PushOutcome.INVALID_TOKEN
        log.warning("fcm_send_rejected", status=response.status_code, body=response.text[:300])
        return PushOutcome.FAILED


def _is_invalid_registration(response: httpx.Response) -> bool:
    """True when FCM says the registration will never be valid again."""
    try:
        error = response.json().get("error", {})
    except ValueError:
        return False
    codes = {detail.get("errorCode") for detail in error.get("details", [])}
    if "UNREGISTERED" in codes:
        return True
    # A malformed registration is reported as INVALID_ARGUMENT, which FCM also
    # uses for payload mistakes; only the former names the registration token.
    return (
        error.get("status") == "INVALID_ARGUMENT"
        and "registration token" in str(error.get("message", "")).lower()
    )
