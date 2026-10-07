"""FastAPI dependencies shared by every router."""

from typing import Annotated

from fastapi import Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.client import ClientInfo
from app.core.db import get_session

# scope="function" commits before the response is sent, so a client never
# receives a success for work that then fails to commit.
SessionDep = Annotated[AsyncSession, Depends(get_session, scope="function")]


def get_client_info(request: Request) -> ClientInfo:
    user_agent = request.headers.get("user-agent")
    return ClientInfo(
        ip=request.client.host if request.client else None,
        user_agent=user_agent[:500] if user_agent else None,
    )


ClientInfoDep = Annotated[ClientInfo, Depends(get_client_info)]
