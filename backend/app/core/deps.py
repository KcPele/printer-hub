"""FastAPI dependencies shared by every router."""

from typing import Annotated

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session

# scope="function" commits before the response is sent, so a client never
# receives a success for work that then fails to commit.
SessionDep = Annotated[AsyncSession, Depends(get_session, scope="function")]
