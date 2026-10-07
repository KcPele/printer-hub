import uuid

from fastapi import APIRouter, status

from app.core.deps import ClientInfoDep, SessionDep
from app.core.errors import problem_responses
from app.modules.auth import service
from app.modules.auth.deps import Auth
from app.modules.auth.schemas import (
    AuthResponse,
    ChangePasswordRequest,
    EmailVerifyRequest,
    LoginRequest,
    PasswordForgotRequest,
    PasswordResetRequest,
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


@router.post(
    "/password/forgot", status_code=status.HTTP_204_NO_CONTENT, responses=problem_responses(429)
)
async def forgot_password(
    payload: PasswordForgotRequest, session: SessionDep, client: ClientInfoDep
) -> None:
    """Email a 6-digit reset code.

    Always answers 204, whether or not the address has an account.
    """
    await service.request_password_reset(session, email=payload.email, client=client)


@router.post(
    "/password/reset", status_code=status.HTTP_204_NO_CONTENT, responses=problem_responses(429)
)
async def reset_password(
    payload: PasswordResetRequest, session: SessionDep, client: ClientInfoDep
) -> None:
    """Choose a new password using the emailed code. Signs out every session.

    A code works once, expires after a few minutes, and stops working after
    a few wrong attempts.
    """
    await service.reset_password(
        session,
        email=payload.email,
        code=payload.code,
        new_password=payload.new_password,
        client=client,
    )


@router.post("/email/verify")
async def verify_email(payload: EmailVerifyRequest, auth: Auth, session: SessionDep) -> UserRead:
    """Confirm the caller's email address with the code sent at sign-up."""
    user = await service.verify_email(session, user=auth.user, code=payload.code)
    return UserRead.model_validate(user)


@router.post(
    "/email/resend", status_code=status.HTTP_204_NO_CONTENT, responses=problem_responses(429)
)
async def resend_verification(auth: Auth, session: SessionDep) -> None:
    """Email a new verification code. Any earlier code stops working."""
    await service.resend_verification(session, auth.user)


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
