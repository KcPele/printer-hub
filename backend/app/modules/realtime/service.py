"""Connection details and channel authorization for live updates."""

import re
import uuid
from urllib.parse import urlsplit

from sqlalchemy.ext.asyncio import AsyncSession

from app.adapters.realtime.pusher import sign_channel_auth
from app.core import events
from app.core.config import get_settings
from app.core.errors import PermissionDeniedError
from app.core.permissions import Permission, role_has
from app.modules.organizations import service as organizations
from app.modules.realtime.schemas import RealtimeChannels, RealtimeConfig
from app.modules.users.models import User

_UUID = r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
_USER_CHANNEL = re.compile(rf"^private-user-(?P<user_id>{_UUID})$")
_ORG_CHANNEL = re.compile(rf"^private-org-(?P<org_id>{_UUID})(?P<jobs>-jobs)?$")
_SOCKET_ID = re.compile(r"^\d+\.\d+$")


def client_config(user: User, *, auth_endpoint: str) -> RealtimeConfig:
    settings = get_settings()
    url = urlsplit(settings.soketi_public_url or settings.soketi_url)
    use_tls = url.scheme in ("https", "wss")
    placeholder = uuid.UUID(int=0)
    return RealtimeConfig(
        app_key=settings.soketi_app_key,
        host=url.hostname or "localhost",
        port=url.port or (443 if use_tls else 80),
        use_tls=use_tls,
        auth_endpoint=auth_endpoint,
        channels=RealtimeChannels(
            user=events.user_channel(user.id),
            organization=events.org_channel(placeholder).replace(
                str(placeholder), "{organization_id}"
            ),
            organization_jobs=events.org_jobs_channel(placeholder).replace(
                str(placeholder), "{organization_id}"
            ),
        ),
    )


async def _may_subscribe(session: AsyncSession, user: User, channel: str) -> bool:
    if match := _USER_CHANNEL.match(channel):
        return match["user_id"] == str(user.id)
    if match := _ORG_CHANNEL.match(channel):
        found = await organizations.get_membership(
            session, organization_id=uuid.UUID(match["org_id"]), user_id=user.id
        )
        if found is None:
            return False
        _, membership = found
        needed = Permission.JOBS_READ_ALL if match["jobs"] else Permission.PRINTERS_READ
        return role_has(membership.role, needed)
    return False


async def authorize_channel(
    session: AsyncSession, *, user: User, socket_id: str, channel: str
) -> str:
    """Return the signed `auth` value for a subscription the caller is allowed to make."""
    if not _SOCKET_ID.match(socket_id) or not await _may_subscribe(session, user, channel):
        raise PermissionDeniedError(
            "realtime.channel_forbidden", "You cannot subscribe to this channel."
        )
    settings = get_settings()
    return sign_channel_auth(
        settings.soketi_app_key,
        settings.soketi_app_secret.get_secret_value(),
        socket_id,
        channel,
    )
