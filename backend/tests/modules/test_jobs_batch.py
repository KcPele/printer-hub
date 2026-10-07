import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

import httpx
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.jobs.models import Job, JobEvent
from tests.factories import create_connection
from tests.modules.test_jobs import Scene, make_scene

API = "/api/v1"


def _at(minutes_ago: int) -> str:
    return (datetime.now(UTC) - timedelta(minutes=minutes_ago)).isoformat()


def _item(scene: Scene, *, events: list[dict[str, Any]], **job: Any) -> dict[str, Any]:
    return {
        "idempotency_key": uuid.uuid4().hex,
        "job": scene.print_job(id=str(uuid.uuid7()), **job),
        "events": events,
    }


async def test_offline_jobs_sync_with_their_history(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    connection = await create_connection(session, scene.printer)
    printed = _item(
        scene,
        title="Printed offline.pdf",
        submitted_at=_at(30),
        events=[
            {"status": "processing", "occurred_at": _at(29), "connection_id": str(connection.id)},
            {"status": "printing", "occurred_at": _at(28)},
            {"status": "completed", "occurred_at": _at(27), "page_count": 4},
        ],
    )
    failed = _item(
        scene,
        title="Failed offline.pdf",
        submitted_at=_at(20),
        events=[{"status": "failed", "occurred_at": _at(19), "error_code": "ipp.unreachable"}],
    )

    response = await client.post(
        f"{scene.url}/batch", headers=scene.headers, json={"items": [printed, failed]}
    )

    assert response.status_code == 200
    first, second = response.json()["results"]
    assert first["outcome"] == second["outcome"] == "created"
    assert first["job"]["id"] == printed["job"]["id"]
    assert first["job"]["status"] == "completed"
    assert first["job"]["page_count"] == 4
    assert first["job"]["connection_type"] == "ipps"
    # Timestamps come from the device, not from the moment of sync.
    assert first["job"]["completed_at"].startswith(printed["events"][2]["occurred_at"][:19])
    assert second["job"]["status"] == "failed"
    assert second["job"]["error_code"] == "ipp.unreachable"


async def test_replaying_a_batch_changes_nothing(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    batch = {
        "items": [
            _item(
                scene,
                events=[
                    {"status": "printing", "occurred_at": _at(5)},
                    {"status": "completed", "occurred_at": _at(4)},
                ],
            )
        ]
    }
    first = await client.post(f"{scene.url}/batch", headers=scene.headers, json=batch)
    events_before = await session.scalar(select(func.count()).select_from(JobEvent))

    second = await client.post(f"{scene.url}/batch", headers=scene.headers, json=batch)

    assert second.json()["results"][0]["outcome"] == "replayed"
    assert second.json()["results"][0]["job"] == first.json()["results"][0]["job"]
    assert await session.scalar(select(func.count()).select_from(Job)) == 1
    assert await session.scalar(select(func.count()).select_from(JobEvent)) == events_before


async def test_a_later_sync_can_advance_an_existing_job(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    item = _item(scene, events=[{"status": "printing", "occurred_at": _at(10)}])
    await client.post(f"{scene.url}/batch", headers=scene.headers, json={"items": [item]})
    item["events"].append({"status": "completed", "occurred_at": _at(9)})

    # Same key, same job, one more event.
    response = await client.post(
        f"{scene.url}/batch", headers=scene.headers, json={"items": [item]}
    )

    result = response.json()["results"][0]
    assert result["outcome"] == "replayed"
    assert result["job"]["status"] == "completed"


async def test_items_succeed_or_fail_independently(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    good = _item(scene, title="Good.pdf", events=[{"status": "completed"}])
    unknown_printer = _item(scene, title="Lost.pdf", events=[], printer_id=str(uuid.uuid4()))
    bad_history = _item(scene, title="Bad.pdf", events=[{"status": "scanning"}])

    response = await client.post(
        f"{scene.url}/batch",
        headers=scene.headers,
        json={"items": [unknown_printer, good, bad_history]},
    )

    lost, ok, bad = response.json()["results"]
    assert lost["outcome"] == "failed"
    assert lost["error"]["code"] == "printer.not_found"
    assert lost["job"] is None
    assert ok["outcome"] == "created"
    assert bad["outcome"] == "failed"
    assert bad["error"]["code"] == "job.invalid_transition"
    # The failed items left nothing behind, not even their job rows.
    titles = set(await session.scalars(select(Job.title)))
    assert titles == {"Good.pdf"}


async def test_events_are_applied_in_the_order_they_happened(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    item = _item(
        scene,
        events=[
            {"status": "completed", "occurred_at": _at(1)},
            {"status": "processing", "occurred_at": _at(3)},
            {"status": "printing", "occurred_at": _at(2)},
        ],
    )

    response = await client.post(
        f"{scene.url}/batch", headers=scene.headers, json={"items": [item]}
    )

    job = response.json()["results"][0]["job"]
    assert job["status"] == "completed"
    events = (await client.get(f"{scene.url}/{job['id']}/events", headers=scene.headers)).json()
    assert [event["status"] for event in events] == [
        "queued",
        "processing",
        "printing",
        "completed",
    ]


async def test_batch_job_created_singly_is_not_duplicated(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    item = _item(scene, events=[{"status": "completed"}])
    created = await client.post(
        scene.url,
        headers={**scene.headers, "Idempotency-Key": item["idempotency_key"]},
        json=item["job"],
    )

    response = await client.post(
        f"{scene.url}/batch", headers=scene.headers, json={"items": [item]}
    )

    result = response.json()["results"][0]
    assert created.status_code == 201
    assert result["outcome"] == "replayed"
    assert result["job"]["id"] == created.json()["id"]
    assert result["job"]["status"] == "completed"
    assert await session.scalar(select(func.count()).select_from(Job)) == 1
