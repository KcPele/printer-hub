import uuid
from datetime import datetime
from typing import Literal

from pydantic import ConfigDict, EmailStr, Field

from app.core.schemas import ApiModel
from app.modules.users.schemas import UserRead

Password = Field(min_length=8, max_length=128)


class RegisterRequest(ApiModel):
    email: EmailStr
    password: str = Password
    name: str = Field(min_length=1, max_length=200)


class LoginRequest(ApiModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class RefreshRequest(ApiModel):
    refresh_token: str = Field(min_length=1, max_length=512)


class ChangePasswordRequest(ApiModel):
    current_password: str = Field(min_length=1, max_length=128)
    new_password: str = Password


class TokenResponse(ApiModel):
    access_token: str
    refresh_token: str
    token_type: Literal["bearer"] = "bearer"  # noqa: S105
    expires_in: int = Field(description="Access token lifetime in seconds")
    session_id: uuid.UUID


class AuthResponse(ApiModel):
    user: UserRead
    tokens: TokenResponse


class SessionRead(ApiModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    device_id: uuid.UUID | None
    user_agent: str | None
    ip: str | None
    created_at: datetime
    last_used_at: datetime
    expires_at: datetime
    is_current: bool = False


Code = Field(min_length=6, max_length=6, pattern=r"^\d{6}$", examples=["042817"])


class EmailVerifyRequest(ApiModel):
    code: str = Code


class PasswordForgotRequest(ApiModel):
    email: EmailStr


class PasswordResetRequest(ApiModel):
    email: EmailStr
    code: str = Code
    new_password: str = Password
