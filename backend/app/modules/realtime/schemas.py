from typing import Literal

from pydantic import BaseModel, Field


class RealtimeChannels(BaseModel):
    user: str = Field(description="The caller's own channel")
    organization: str = Field(description="Template; replace {organization_id}")
    organization_jobs: str = Field(description="Template; replace {organization_id}")


class RealtimeConnection(BaseModel):
    """What a Pusher client library needs to connect."""

    provider: Literal["pusher"] = "pusher"
    app_key: str
    host: str
    port: int
    use_tls: bool
    auth_endpoint: str
    channels: RealtimeChannels


class RealtimeConfig(BaseModel):
    enabled: bool = Field(
        description=(
            "False when this deployment has no WebSocket server. "
            "Clients then refresh from push data payloads and on screen focus."
        )
    )
    connection: RealtimeConnection | None = None


class ChannelAuthorization(BaseModel):
    auth: str
