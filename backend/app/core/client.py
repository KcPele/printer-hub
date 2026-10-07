"""Facts about the caller's connection, passed from routers to services."""

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class ClientInfo:
    ip: str | None = None
    user_agent: str | None = None
