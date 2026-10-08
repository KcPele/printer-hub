import uuid
from datetime import UTC, datetime

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import NotFoundError
from app.modules.auth.models import UserSession
from app.modules.devices.models import Device
from app.modules.devices.schemas import DeviceRegister, DeviceUpdate


async def register(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    current_session: UserSession,
    payload: DeviceRegister,
) -> Device:
    """Create or update the caller's device and bind it to the current session."""
    device = await session.scalar(
        select(Device).where(
            Device.user_id == user_id, Device.installation_id == payload.installation_id
        )
    )
    if device is None:
        device = Device(user_id=user_id, installation_id=payload.installation_id)
        session.add(device)

    device.platform = payload.platform
    # The name is its owner's to give (PATCH). An app that registers again at
    # each sign-in, without one, must not take it away.
    if payload.name is not None:
        device.name = payload.name
    device.model = payload.model
    device.os_version = payload.os_version
    device.app_version = payload.app_version
    device.push_provider = payload.push_provider
    device.push_token = payload.push_token
    device.last_seen_at = datetime.now(UTC)
    await session.flush()

    if payload.push_token is not None:
        await _release_push_token(session, token=payload.push_token, keep_device_id=device.id)
    current_session.device_id = device.id
    await session.flush()
    return device


async def _release_push_token(
    session: AsyncSession, *, token: str, keep_device_id: uuid.UUID
) -> None:
    """A push token belongs to one device.

    When another account signs in on the same phone, the previous account's
    device row must stop receiving that phone's notifications.
    """
    await session.execute(
        update(Device)
        .where(Device.push_token == token, Device.id != keep_device_id)
        .values(push_token=None, push_provider=None)
    )


async def list_for_user(session: AsyncSession, user_id: uuid.UUID) -> list[Device]:
    devices = await session.scalars(
        select(Device).where(Device.user_id == user_id).order_by(Device.last_seen_at.desc())
    )
    return list(devices)


async def list_push_targets(session: AsyncSession, user_id: uuid.UUID) -> list[Device]:
    devices = await session.scalars(
        select(Device).where(Device.user_id == user_id, Device.push_token.is_not(None))
    )
    return list(devices)


async def get_owned(session: AsyncSession, *, user_id: uuid.UUID, device_id: uuid.UUID) -> Device:
    device = await session.scalar(
        select(Device).where(Device.id == device_id, Device.user_id == user_id)
    )
    if device is None:
        raise NotFoundError("device.not_found", "Device not found.")
    return device


async def update_device(
    session: AsyncSession, *, user_id: uuid.UUID, device_id: uuid.UUID, payload: DeviceUpdate
) -> Device:
    device = await get_owned(session, user_id=user_id, device_id=device_id)
    changes = payload.model_dump(exclude_unset=True)
    for field, value in changes.items():
        setattr(device, field, value)
    device.last_seen_at = datetime.now(UTC)
    await session.flush()
    if changes.get("push_token") is not None:
        await _release_push_token(session, token=changes["push_token"], keep_device_id=device.id)
    return device


async def clear_push_token(session: AsyncSession, device_id: uuid.UUID) -> None:
    await session.execute(
        update(Device).where(Device.id == device_id).values(push_token=None, push_provider=None)
    )


async def delete(session: AsyncSession, *, user_id: uuid.UUID, device_id: uuid.UUID) -> None:
    device = await get_owned(session, user_id=user_id, device_id=device_id)
    await session.delete(device)
    await session.flush()
