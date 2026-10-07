import uuid
from typing import Any

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.adapters.push.base import PushOutcome
from app.adapters.push.memory import MemoryPushProvider
from app.core.permissions import Role
from app.core.tasks import MemoryTaskQueue
from app.modules.devices.models import Device, DevicePlatform, PushProviderName
from app.modules.notifications import service
from app.modules.notifications.models import Notification, NotificationType
from app.modules.users.models import User
from tests.factories import add_member, auth_headers, create_user
from tests.modules.test_jobs import create_job, key, make_scene, report

API = "/api/v1"


async def _device(session: AsyncSession, user: User, token: str | None) -> Device:
    device = Device(
        user_id=user.id,
        installation_id=f"install-{uuid.uuid4().hex}",
        platform=DevicePlatform.ANDROID,
        push_provider=PushProviderName.FCM if token else None,
        push_token=token,
    )
    session.add(device)
    await session.flush()
    return device


async def _notifications(client: httpx.AsyncClient, headers: dict[str, str], **params: Any) -> Any:
    response = await client.get(f"{API}/notifications", headers=headers, params=params)
    assert response.status_code == 200
    return response.json()["items"]


# --- Triggers ----------------------------------------------------------------


async def test_completed_print_notifies_the_owner(
    client: httpx.AsyncClient, session: AsyncSession, task_queue: MemoryTaskQueue
) -> None:
    scene = await make_scene(session)
    job = await create_job(client, scene)

    await report(client, scene, job["id"], status="printing")
    assert await _notifications(client, scene.headers) == []
    await report(client, scene, job["id"], status="completed")

    [notification] = await _notifications(client, scene.headers)
    assert notification["type"] == "job.completed"
    assert notification["title"] == "Print complete"
    assert notification["body"] == "Invoice.pdf was printed on Office Xerox."
    assert notification["data"] == {
        "job_id": job["id"],
        "organization_id": str(scene.organization.id),
        "printer_id": str(scene.printer.id),
        "job_type": "print",
        "status": "completed",
    }
    assert notification["read_at"] is None
    [task] = task_queue.named("push_notification")
    assert task.kwargs == {"notification_id": notification["id"]}


async def test_failed_job_notifies(client: httpx.AsyncClient, session: AsyncSession) -> None:
    scene = await make_scene(session)
    job = await create_job(client, scene)

    await report(client, scene, job["id"], status="failed", error_code="ipp.unreachable")

    [notification] = await _notifications(client, scene.headers)
    assert notification["type"] == "job.failed"
    assert notification["body"] == "Invoice.pdf could not be printed on Office Xerox."


async def test_completed_scan_is_announced_as_scan_ready(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    job = (
        await client.post(
            scene.url,
            headers={**scene.headers, **key()},
            json={"type": "scan", "printer_id": str(scene.printer.id)},
        )
    ).json()

    await report(client, scene, job["id"], status="completed")

    [notification] = await _notifications(client, scene.headers)
    assert notification["type"] == "scan.ready"
    assert notification["title"] == "Scan ready"


async def test_cancellation_notifies_only_when_someone_else_cancels(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    member = await add_member(session, scene.organization, Role.USER)
    member_headers = await auth_headers(session, member)
    own = await create_job(client, scene, headers=member_headers, title="Own.pdf")
    by_admin = await create_job(client, scene, headers=member_headers, title="Stopped.pdf")

    await client.post(f"{scene.url}/{own['id']}/cancel", headers=member_headers)
    await client.post(f"{scene.url}/{by_admin['id']}/cancel", headers=scene.headers)

    [notification] = await _notifications(client, member_headers)
    assert notification["type"] == "job.cancelled"
    assert notification["body"] == "Stopped.pdf was cancelled by an administrator."
    assert await _notifications(client, scene.headers) == []


async def test_offline_sync_does_not_send_stale_notifications(
    client: httpx.AsyncClient, session: AsyncSession, task_queue: MemoryTaskQueue
) -> None:
    scene = await make_scene(session)

    response = await client.post(
        f"{scene.url}/batch",
        headers=scene.headers,
        json={
            "items": [
                {
                    "idempotency_key": uuid.uuid4().hex,
                    "job": scene.print_job(),
                    "events": [{"status": "completed"}],
                }
            ]
        },
    )

    assert response.json()["results"][0]["job"]["status"] == "completed"
    assert await _notifications(client, scene.headers) == []
    assert task_queue.enqueued == []


async def test_failed_request_queues_no_push(
    client: httpx.AsyncClient, session: AsyncSession, task_queue: MemoryTaskQueue
) -> None:
    scene = await make_scene(session)
    job = await create_job(client, scene)
    await report(client, scene, job["id"], status="completed")
    task_queue.enqueued.clear()

    rejected = await report(client, scene, job["id"], status="failed")

    assert rejected.status_code == 409
    assert task_queue.enqueued == []
    assert len(await _notifications(client, scene.headers)) == 1


async def test_muted_type_is_listed_but_not_pushed(
    client: httpx.AsyncClient, session: AsyncSession, task_queue: MemoryTaskQueue
) -> None:
    scene = await make_scene(session)
    await client.patch(
        f"{API}/users/me",
        headers=scene.headers,
        json={"preferences": {"muted_notification_types": ["job.completed"]}},
    )
    done = await create_job(client, scene)
    failed = await create_job(client, scene)

    await report(client, scene, done["id"], status="completed")
    await report(client, scene, failed["id"], status="failed")

    assert {n["type"] for n in await _notifications(client, scene.headers)} == {
        "job.completed",
        "job.failed",
    }
    assert len(task_queue.named("push_notification")) == 1


# --- Reading -----------------------------------------------------------------


async def test_read_state(client: httpx.AsyncClient, session: AsyncSession) -> None:
    user = await create_user(session)
    headers = await auth_headers(session, user)
    for number in range(3):
        await service.notify(
            session,
            user_id=user.id,
            type=NotificationType.JOB_COMPLETED,
            title=f"Notification {number}",
            body="Body",
        )

    items = await _notifications(client, headers)
    assert [item["title"] for item in items] == [
        "Notification 2",
        "Notification 1",
        "Notification 0",
    ]
    assert (await client.get(f"{API}/notifications/unread-count", headers=headers)).json() == {
        "unread": 3
    }

    read = await client.post(f"{API}/notifications/{items[0]['id']}/read", headers=headers)
    assert read.status_code == 200
    assert read.json()["read_at"] is not None
    unread = await _notifications(client, headers, unread_only=True)
    assert [item["title"] for item in unread] == ["Notification 1", "Notification 0"]

    assert (await client.post(f"{API}/notifications/read-all", headers=headers)).status_code == 204
    assert (await client.get(f"{API}/notifications/unread-count", headers=headers)).json() == {
        "unread": 0
    }


async def test_notifications_are_private(client: httpx.AsyncClient, session: AsyncSession) -> None:
    alice, bob = await create_user(session), await create_user(session)
    notification = await service.notify(
        session, user_id=alice.id, type=NotificationType.JOB_FAILED, title="T", body="B"
    )
    bob_headers = await auth_headers(session, bob)

    assert await _notifications(client, bob_headers) == []
    response = await client.post(f"{API}/notifications/{notification.id}/read", headers=bob_headers)
    assert response.status_code == 404


# --- Push delivery -----------------------------------------------------------


async def test_push_goes_to_every_device_with_a_token(
    session: AsyncSession, push: MemoryPushProvider
) -> None:
    user = await create_user(session)
    await _device(session, user, "token-phone")
    await _device(session, user, "token-tablet")
    await _device(session, user, None)
    await _device(session, await create_user(session), "token-someone-else")
    notification = await service.notify(
        session,
        user_id=user.id,
        type=NotificationType.JOB_COMPLETED,
        title="Print complete",
        body="Invoice.pdf was printed.",
        data={"job_id": "j-1"},
    )

    failed = await service.deliver_push(session, notification.id)

    assert failed == []
    assert sorted(token for token, _ in push.sent) == ["token-phone", "token-tablet"]
    _, message = push.sent[0]
    assert message.title == "Print complete"
    # The data payload lets an open app refresh the right screen.
    assert message.data == {
        "job_id": "j-1",
        "type": "job.completed",
        "notification_id": str(notification.id),
    }


async def test_invalid_token_is_cleared_and_temporary_failure_is_reported(
    session: AsyncSession, push: MemoryPushProvider
) -> None:
    user = await create_user(session)
    gone = await _device(session, user, "token-uninstalled")
    flaky = await _device(session, user, "token-flaky")
    fine = await _device(session, user, "token-fine")
    push.outcomes = {
        "token-uninstalled": PushOutcome.INVALID_TOKEN,
        "token-flaky": PushOutcome.FAILED,
    }
    notification = await service.notify(
        session, user_id=user.id, type=NotificationType.JOB_FAILED, title="T", body="B"
    )

    failed = await service.deliver_push(session, notification.id)

    assert failed == [flaky.id]
    assert [token for token, _ in push.sent] == ["token-fine"]
    tokens = dict(
        (
            await session.execute(
                select(Device.id, Device.push_token).execution_options(populate_existing=True)
            )
        ).all()
    )
    assert tokens[gone.id] is None
    assert tokens[flaky.id] == "token-flaky"
    assert tokens[fine.id] == "token-fine"

    # A retry targets only the device that failed.
    push.reset()
    assert await service.deliver_push(session, notification.id, device_ids=[flaky.id]) == []
    assert [token for token, _ in push.sent] == ["token-flaky"]


async def test_delivering_a_deleted_notification_is_a_no_op(
    session: AsyncSession, push: MemoryPushProvider
) -> None:
    assert await service.deliver_push(session, uuid.uuid4()) == []
    assert push.sent == []
    assert await session.scalar(select(Notification).limit(1)) is None
