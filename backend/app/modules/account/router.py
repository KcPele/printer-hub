from fastapi import APIRouter, status

from app.core.deps import SessionDep
from app.core.errors import problem_responses
from app.modules.account import service
from app.modules.account.schemas import AccountDeleteRequest
from app.modules.auth.deps import CurrentUser

router = APIRouter(prefix="/account", tags=["account"])


@router.post("/delete", status_code=status.HTTP_204_NO_CONTENT, responses=problem_responses(409))
async def delete_account(
    payload: AccountDeleteRequest, user: CurrentUser, session: SessionDep
) -> None:
    """Permanently delete the caller's account. This cannot be undone.

    Organizations where the caller is the only member are deleted with it.
    Answers 409 while the caller is the last owner of an organization that
    has other members.
    """
    await service.delete_account(session, user=user, password=payload.password)
