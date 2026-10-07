import uuid

from fastapi import APIRouter, status

from app.core.deps import ClientInfoDep, SessionDep
from app.core.errors import problem_responses
from app.modules.auth import service
from app.modules.auth.deps import Auth
from app.modules.auth.schemas import (
    AuthResponse,
    ChangePasswordRequest,
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    SessionRead,
    TokenResponse,
)
from app.modules.auth.service import IssuedTokens
from app.modules.users.schemas import UserRead

router = APIRouter(prefix="/auth", tags=["auth"])


def _token_response(tokens: IssuedTokens) -> TokenResponse:
    return TokenResponse(
        access_token=tokens.access_token,
        refresh_token=tokens.refresh_token,
        expires_in=tokens.expires_in,
        session_id=tokens.session_id,
    )


@router.post(
    "/register", status_code=status.HTTP_201_CREATED, responses=problem_responses(409, 429)
)
async def register(
    payload: RegisterRequest, session: SessionDep, client: ClientInfoDep
) -> AuthResponse:
    user, tokens = await service.register(
        session, email=payload.email, password=payload.password, name=payload.name, client=client
    )
    return AuthResponse(user=UserRead.model_validate(user), tokens=_token_response(tokens))


@router.post("/login", responses=problem_responses(429))
async def login(payload: LoginRequest, session: SessionDep, client: ClientInfoDep) -> AuthResponse:
    user, tokens = await service.login(
        session, email=payload.email, password=payload.password, client=client
    )
    return AuthResponse(user=UserRead.model_validate(user), tokens=_token_response(tokens))


@router.post("/refresh")
async def refresh(
    payload: RefreshRequest, session: SessionDep, client: ClientInfoDep
) -> TokenResponse:
    """Rotate the refresh token. The submitted token stops working.

    Submitting an already rotated token revokes the session.
    """
    tokens = await service.refresh(session, refresh_token=payload.refresh_token, client=client)
    return _token_response(tokens)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(auth: Auth, session: SessionDep) -> None:
    await service.logout(session, auth.session)


@router.post("/password/change", status_code=status.HTTP_204_NO_CONTENT)
async def change_password(payload: ChangePasswordRequest, auth: Auth, session: SessionDep) -> None:
    """Change the password and sign out every other session."""
    await service.change_password(
        session,
        user=auth.user,
        current_session=auth.session,
        current_password=payload.current_password,
        new_password=payload.new_password,
    )


@router.get("/sessions")
async def list_sessions(auth: Auth, session: SessionDep) -> list[SessionRead]:
    rows = await service.list_sessions(session, auth.user.id)
    return [
        SessionRead.model_validate(row).model_copy(update={"is_current": row.id == auth.session.id})
        for row in rows
    ]


@router.delete("/sessions/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
async def revoke_session(session_id: uuid.UUID, auth: Auth, session: SessionDep) -> None:
    await service.revoke_session(session, user_id=auth.user.id, session_id=session_id)
