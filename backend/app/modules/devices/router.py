import uuid

from fastapi import APIRouter, status

from app.core.deps import SessionDep
from app.modules.auth.deps import Auth
from app.modules.devices import service
from app.modules.devices.schemas import DeviceRead, DeviceRegister, DeviceUpdate

router = APIRouter(prefix="/devices", tags=["devices"])


@router.post("")
async def register_device(payload: DeviceRegister, auth: Auth, session: SessionDep) -> DeviceRead:
    """Register this installation, or update it if it is already known.

    Call after every sign-in and whenever the push token changes.
    """
    device = await service.register(
        session, user_id=auth.user.id, current_session=auth.session, payload=payload
    )
    return DeviceRead.model_validate(device)


@router.get("")
async def list_devices(auth: Auth, session: SessionDep) -> list[DeviceRead]:
    devices = await service.list_for_user(session, auth.user.id)
    return [DeviceRead.model_validate(device) for device in devices]


@router.patch("/{device_id}")
async def update_device(
    device_id: uuid.UUID, payload: DeviceUpdate, auth: Auth, session: SessionDep
) -> DeviceRead:
    device = await service.update_device(
        session, user_id=auth.user.id, device_id=device_id, payload=payload
    )
    return DeviceRead.model_validate(device)


@router.delete("/{device_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_device(device_id: uuid.UUID, auth: Auth, session: SessionDep) -> None:
    await service.delete(session, user_id=auth.user.id, device_id=device_id)
