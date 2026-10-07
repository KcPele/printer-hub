from typing import Annotated

from fastapi import APIRouter, Form

from app.core.deps import SessionDep
from app.modules.auth.deps import CurrentUser
from app.modules.realtime import service
from app.modules.realtime.schemas import ChannelAuthorization, RealtimeConfig

router = APIRouter(prefix="/realtime", tags=["realtime"])

AUTH_ENDPOINT = "/api/v1/realtime/auth"


@router.get("/config")
async def get_config(user: CurrentUser) -> RealtimeConfig:
    """Connection details for the live-update WebSocket server."""
    return service.client_config(user, auth_endpoint=AUTH_ENDPOINT)


@router.post("/auth")
async def authorize_channel(
    user: CurrentUser,
    session: SessionDep,
    socket_id: Annotated[str, Form(max_length=64)],
    channel_name: Annotated[str, Form(max_length=200)],
) -> ChannelAuthorization:
    """Authorize a private-channel subscription.

    Pusher client libraries call this endpoint themselves. Configure the
    client to send the access token in the `Authorization` header.
    """
    auth = await service.authorize_channel(
        session, user=user, socket_id=socket_id, channel=channel_name
    )
    return ChannelAuthorization(auth=auth)
