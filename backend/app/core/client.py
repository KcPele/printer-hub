"""Facts about the caller's connection."""

from contextvars import ContextVar
from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class ClientInfo:
    ip: str | None = None
    user_agent: str | None = None


# Set per request by RequestContextMiddleware. The audit log reads it so that
# services do not have to thread connection details through every call.
current_client: ContextVar[ClientInfo] = ContextVar("current_client", default=ClientInfo())  # noqa: B039
