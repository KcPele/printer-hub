from fastapi import APIRouter

from app.core.deps import SessionDep
from app.modules.auth.deps import CurrentUser
from app.modules.users import service
from app.modules.users.schemas import UserRead, UserUpdate

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me")
async def get_me(user: CurrentUser) -> UserRead:
    return UserRead.model_validate(user)


@router.patch("/me")
async def update_me(payload: UserUpdate, user: CurrentUser, session: SessionDep) -> UserRead:
    updated = await service.update_profile(session, user, payload)
    return UserRead.model_validate(updated)
