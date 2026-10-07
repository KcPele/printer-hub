"""Authentication dependencies."""

from dataclasses import dataclass
from typing import Annotated

import structlog
from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.deps import SessionDep
from app.core.errors import PermissionDeniedError, UnauthorizedError
from app.modules.auth import service
from app.modules.auth.models import UserSession
from app.modules.users.models import User

_bearer = HTTPBearer(auto_error=False, description="Access token from /auth/login")


@dataclass(frozen=True, slots=True)
class AuthContext:
    user: User
    session: UserSession


async def get_auth_context(
    session: SessionDep,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
) -> AuthContext:
    if credentials is None:
        raise UnauthorizedError("auth.missing_token", "Sign in to continue.")
    user, user_session = await service.authenticate(session, credentials.credentials)
    structlog.contextvars.bind_contextvars(user_id=str(user.id))
    return AuthContext(user=user, session=user_session)


Auth = Annotated[AuthContext, Depends(get_auth_context)]


def get_current_user(auth: Auth) -> User:
    return auth.user


CurrentUser = Annotated[User, Depends(get_current_user)]


def get_superuser(auth: Auth) -> User:
    if not auth.user.is_superuser:
        raise PermissionDeniedError(
            "permission.superuser_required", "This action needs a platform administrator."
        )
    return auth.user


SuperUser = Annotated[User, Depends(get_superuser)]
