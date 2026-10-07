"""Accounts, sign-in, and session lifecycle (FRD §18)."""

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from functools import lru_cache

from anyio import to_thread
from sqlalchemy import delete, or_, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.adapters.email.base import EmailMessage
from app.core import tasks
from app.core.client import ClientInfo
from app.core.config import get_settings
from app.core.errors import ConflictError, UnauthorizedError, ValidationFailedError
from app.core.ratelimit import enforce_rate_limit
from app.core.security import (
    create_access_token,
    decode_access_token,
    generate_token,
    hash_password,
    hash_token,
    verify_password,
)
from app.modules.audit import service as audit
from app.modules.auth import email_codes, emails
from app.modules.auth.email_codes import CodePurpose
from app.modules.auth.models import UserSession
from app.modules.users import service as users
from app.modules.users.models import User


@dataclass(frozen=True, slots=True)
class IssuedTokens:
    access_token: str
    refresh_token: str
    expires_in: int
    session_id: uuid.UUID


@lru_cache
def _decoy_hash() -> str:
    return hash_password("decoy-password-for-unknown-accounts")


SEND_EMAIL_TASK = "send_email"


def _queue_email(session: AsyncSession, message: EmailMessage) -> None:
    tasks.enqueue(
        session, SEND_EMAIL_TASK, to=message.to, subject=message.subject, text=message.text
    )


async def _send_verification_code(session: AsyncSession, user: User) -> None:
    code = await email_codes.issue(session, user_id=user.id, purpose=CodePurpose.EMAIL_VERIFICATION)
    _queue_email(session, emails.verification(user.email, user.name, code))


def _invalid_code() -> ValidationFailedError:
    return ValidationFailedError(
        "auth.code_invalid", "That code is not valid or has expired. Request a new one."
    )


async def _limit_code_requests(bucket: str, identifier: str) -> None:
    settings = get_settings()
    await enforce_rate_limit(
        bucket,
        identifier,
        limit=settings.email_code_rate_limit_attempts,
        window_seconds=settings.email_code_rate_limit_window_seconds,
    )


def _invalid_credentials() -> UnauthorizedError:
    return UnauthorizedError("auth.invalid_credentials", "Incorrect email or password.")


async def _open_session(session: AsyncSession, user: User, client: ClientInfo) -> IssuedTokens:
    settings = get_settings()
    refresh_token = generate_token()
    user_session = UserSession(
        user_id=user.id,
        refresh_token_hash=hash_token(refresh_token),
        user_agent=client.user_agent,
        ip=client.ip,
        expires_at=datetime.now(UTC) + timedelta(days=settings.refresh_token_ttl_days),
    )
    session.add(user_session)
    await session.flush()
    access_token, expires_in = create_access_token(user.id, user_session.id)
    return IssuedTokens(access_token, refresh_token, expires_in, user_session.id)


async def register(
    session: AsyncSession, *, email: str, password: str, name: str, client: ClientInfo
) -> tuple[User, IssuedTokens]:
    settings = get_settings()
    await enforce_rate_limit(
        "register",
        client.ip or "unknown",
        limit=settings.register_rate_limit_attempts,
        window_seconds=settings.register_rate_limit_window_seconds,
    )

    user = User(
        email=users.normalize_email(email),
        password_hash=await to_thread.run_sync(hash_password, password),
        name=name.strip(),
    )
    session.add(user)
    try:
        await session.flush()
    except IntegrityError as exc:
        raise ConflictError(
            "auth.email_taken", "An account with this email already exists."
        ) from exc
    await _send_verification_code(session, user)
    return user, await _open_session(session, user, client)


async def login(
    session: AsyncSession, *, email: str, password: str, client: ClientInfo
) -> tuple[User, IssuedTokens]:
    settings = get_settings()
    normalized = users.normalize_email(email)
    await enforce_rate_limit(
        "login",
        f"{normalized}|{client.ip or 'unknown'}",
        limit=settings.login_rate_limit_attempts,
        window_seconds=settings.login_rate_limit_window_seconds,
    )

    user = await users.get_by_email(session, normalized)
    # Verify against a decoy when the account is unknown, so response time
    # does not reveal which emails are registered.
    password_hash = user.password_hash if user else _decoy_hash()
    password_ok = await to_thread.run_sync(verify_password, password, password_hash)
    if user is None or not password_ok or not user.is_active:
        raise _invalid_credentials()
    tokens = await _open_session(session, user, client)
    audit.record(
        session,
        action="user.logged_in",
        target_type="session",
        target_id=tokens.session_id,
        actor_user_id=user.id,
    )
    return user, tokens


async def refresh(session: AsyncSession, *, refresh_token: str, client: ClientInfo) -> IssuedTokens:
    """Exchange a refresh token for a new pair. Each refresh token works once."""
    invalid = UnauthorizedError("auth.refresh_token_invalid", "The refresh token is not valid.")
    token_hash = hash_token(refresh_token)
    user_session = await session.scalar(
        select(UserSession)
        .where(
            or_(
                UserSession.refresh_token_hash == token_hash,
                UserSession.previous_refresh_token_hash == token_hash,
            )
        )
        .with_for_update()
    )
    now = datetime.now(UTC)
    if user_session is None or not user_session.is_usable(now):
        raise invalid

    if user_session.previous_refresh_token_hash == token_hash:
        user_session.revoked_at = now
        # Committed here on purpose: raising rolls the request back, and the
        # revocation has to survive it.
        await session.commit()
        raise UnauthorizedError(
            "auth.refresh_token_reused",
            "This refresh token was already used. Sign in again.",
        )

    user = await users.get_by_id(session, user_session.user_id)
    if user is None or not user.is_active:
        raise invalid

    settings = get_settings()
    new_refresh_token = generate_token()
    user_session.previous_refresh_token_hash = user_session.refresh_token_hash
    user_session.refresh_token_hash = hash_token(new_refresh_token)
    user_session.last_used_at = now
    user_session.expires_at = now + timedelta(days=settings.refresh_token_ttl_days)
    user_session.ip = client.ip
    user_session.user_agent = client.user_agent
    await session.flush()

    access_token, expires_in = create_access_token(user.id, user_session.id)
    return IssuedTokens(access_token, new_refresh_token, expires_in, user_session.id)


async def authenticate(session: AsyncSession, access_token: str) -> tuple[User, UserSession]:
    """Resolve an access token to its user and live session."""
    claims = decode_access_token(access_token)
    row = (
        await session.execute(
            select(User, UserSession)
            .join(UserSession, UserSession.user_id == User.id)
            .where(UserSession.id == claims.session_id, User.id == claims.user_id)
        )
    ).one_or_none()
    if row is None:
        raise UnauthorizedError("auth.session_revoked", "This session is no longer active.")
    user, user_session = row
    if not user.is_active or not user_session.is_usable(datetime.now(UTC)):
        raise UnauthorizedError("auth.session_revoked", "This session is no longer active.")
    return user, user_session


async def logout(session: AsyncSession, user_session: UserSession) -> None:
    user_session.revoked_at = datetime.now(UTC)
    await session.flush()


async def list_sessions(session: AsyncSession, user_id: uuid.UUID) -> list[UserSession]:
    rows = await session.scalars(
        select(UserSession)
        .where(
            UserSession.user_id == user_id,
            UserSession.revoked_at.is_(None),
            UserSession.expires_at > datetime.now(UTC),
        )
        .order_by(UserSession.last_used_at.desc())
    )
    return list(rows)


async def revoke_session(
    session: AsyncSession, *, user_id: uuid.UUID, session_id: uuid.UUID
) -> None:
    """Idempotent: revoking an unknown or already revoked session succeeds."""
    await session.execute(
        update(UserSession)
        .where(
            UserSession.id == session_id,
            UserSession.user_id == user_id,
            UserSession.revoked_at.is_(None),
        )
        .values(revoked_at=datetime.now(UTC))
    )


async def change_password(
    session: AsyncSession,
    *,
    user: User,
    current_session: UserSession,
    current_password: str,
    new_password: str,
) -> None:
    """Set a new password and sign out every other session."""
    if not await to_thread.run_sync(verify_password, current_password, user.password_hash):
        raise ValidationFailedError(
            "auth.current_password_incorrect", "The current password is incorrect."
        )
    user.password_hash = await to_thread.run_sync(hash_password, new_password)
    audit.record(
        session,
        action="user.password_changed",
        target_type="user",
        target_id=user.id,
        actor_user_id=user.id,
    )
    await session.execute(
        update(UserSession)
        .where(
            UserSession.user_id == user.id,
            UserSession.id != current_session.id,
            UserSession.revoked_at.is_(None),
        )
        .values(revoked_at=datetime.now(UTC))
    )
    await session.flush()


async def purge_dead_sessions(session: AsyncSession, *, older_than_days: int = 30) -> None:
    """Delete sessions that expired or were revoked more than `older_than_days` ago."""
    cutoff = datetime.now(UTC) - timedelta(days=older_than_days)
    await session.execute(
        delete(UserSession).where(
            or_(UserSession.expires_at < cutoff, UserSession.revoked_at < cutoff)
        )
    )


# --- Email verification ------------------------------------------------------


async def resend_verification(session: AsyncSession, user: User) -> None:
    """Email a fresh verification code. Does nothing for an already verified address."""
    if user.email_verified_at is not None:
        return
    await _limit_code_requests("email_verification", str(user.id))
    await _send_verification_code(session, user)


async def verify_email(session: AsyncSession, *, user: User, code: str) -> User:
    if user.email_verified_at is not None:
        return user
    redeemed = await email_codes.redeem(
        session, user_id=user.id, purpose=CodePurpose.EMAIL_VERIFICATION, code=code
    )
    if not redeemed:
        # Committed on purpose: the failed attempt must count against the code.
        await session.commit()
        raise _invalid_code()
    user.email_verified_at = datetime.now(UTC)
    audit.record(
        session,
        action="user.email_verified",
        target_type="user",
        target_id=user.id,
        actor_user_id=user.id,
    )
    await session.flush()
    return user


# --- Password reset ----------------------------------------------------------


async def request_password_reset(session: AsyncSession, *, email: str, client: ClientInfo) -> None:
    """Email a reset code if the address belongs to an account.

    Returns the same way whether or not it does, so the endpoint cannot be
    used to find out which emails are registered.
    """
    normalized = users.normalize_email(email)
    await _limit_code_requests("password_reset", f"{normalized}|{client.ip or 'unknown'}")
    user = await users.get_by_email(session, normalized)
    if user is None or not user.is_active:
        return
    code = await email_codes.issue(session, user_id=user.id, purpose=CodePurpose.PASSWORD_RESET)
    _queue_email(session, emails.password_reset(user.email, user.name, code))


async def reset_password(
    session: AsyncSession, *, email: str, code: str, new_password: str, client: ClientInfo
) -> None:
    """Set a new password with an emailed code, and sign out every session."""
    normalized = users.normalize_email(email)
    await _limit_code_requests("password_reset_confirm", f"{normalized}|{client.ip or 'unknown'}")
    user = await users.get_by_email(session, normalized)
    redeemed = (
        user is not None
        and user.is_active
        and await email_codes.redeem(
            session, user_id=user.id, purpose=CodePurpose.PASSWORD_RESET, code=code
        )
    )
    if user is None or not redeemed:
        # Committed on purpose: the failed attempt must count against the code.
        await session.commit()
        raise _invalid_code()

    user.password_hash = await to_thread.run_sync(hash_password, new_password)
    if user.email_verified_at is None:
        # Using a code from the inbox proves the address is theirs.
        user.email_verified_at = datetime.now(UTC)
    await session.execute(
        update(UserSession)
        .where(UserSession.user_id == user.id, UserSession.revoked_at.is_(None))
        .values(revoked_at=datetime.now(UTC))
    )
    audit.record(
        session,
        action="user.password_reset",
        target_type="user",
        target_id=user.id,
        actor_user_id=user.id,
    )
    await session.flush()
