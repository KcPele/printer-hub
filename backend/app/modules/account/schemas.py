from pydantic import Field

from app.core.schemas import ApiModel


class AccountDeleteRequest(ApiModel):
    password: str = Field(min_length=1, max_length=128, description="The current password")
