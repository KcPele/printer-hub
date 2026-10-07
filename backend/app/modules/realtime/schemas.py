from pydantic import BaseModel, Field


class RealtimeChannels(BaseModel):
    user: str = Field(description="The caller's own channel")
    organization: str = Field(description="Template; replace {organization_id}")
    organization_jobs: str = Field(description="Template; replace {organization_id}")


class RealtimeConfig(BaseModel):
    """What a Pusher client library needs to connect to live updates."""

    provider: str = "pusher"
    app_key: str
    host: str
    port: int
    use_tls: bool
    auth_endpoint: str
    channels: RealtimeChannels


class ChannelAuthorization(BaseModel):
    auth: str
