import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

import httpx
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.permissions import Role
from app.modules.jobs.models import Job
from app.modules.organizations.models import Organization
from app.modules.printers.models import Printer
from app.modules.users.models import User
from tests.factories import (
    add_member,
    auth_headers,
    create_connection,
    create_organization,
    create_printer,
    create_user,
    member_headers,
)

API = "/api/v1"


class Scene:
    """An organization with one printer and its owner signed in."""

    def __init__(
        self, owner: User, organization: Organization, printer: Printer, headers: dict[str, str]
    ) -> None:
        self.owner = owner
        self.organization = organization
        self.printer = printer
        self.headers = headers
        self.url = f"{API}/organizations/{organization.id}/jobs"

    def print_job(self, **overrides: Any) -> dict[str, Any]:
        body: dict[str, Any] = {
            "type": "print",
            "printer_id": str(self.printer.id),
            "title": "Invoice.pdf",
            "page_count": 3,
            "settings": {"copies": 2, "color_mode": "monochrome", "duplex": "two_sided_long_edge"},
        }
        body.update(overrides)
        return body


async def make_scene(session: AsyncSession, **organization: Any) -> Scene:
    owner = await create_user(session)
    org = await create_organization(session, owner, **organization)
    printer = await create_printer(session, org)
    return Scene(owner, org, printer, await auth_headers(session, owner))


def key() -> dict[str, str]:
    return {"Idempotency-Key": uuid.uuid4().hex}


async def create_job(
    client: httpx.AsyncClient, scene: Scene, headers: dict[str, str] | None = None, **overrides: Any
) -> dict[str, Any]:
    response = await client.post(
        scene.url,
        headers={**(headers or scene.headers), **key()},
        json=scene.print_job(**overrides),
    )
    assert response.status_code == 201, response.text
    body: dict[str, Any] = response.json()
    return body


async def report(
    client: httpx.AsyncClient,
    scene: Scene,
    job_id: str,
    headers: dict[str, str] | None = None,
    **event: Any,
) -> httpx.Response:
    return await client.post(
        f"{scene.url}/{job_id}/events", headers=headers or scene.headers, json=event
    )


# --- Creation and idempotency ------------------------------------------------


async def test_create_print_job(client: httpx.AsyncClient, session: AsyncSession) -> None:
    scene = await make_scene(session)

    job = await create_job(client, scene)

    assert job["type"] == "print"
    assert job["status"] == "queued"
    assert job["execution_mode"] == "local"
    assert job["user_id"] == str(scene.owner.id)
    assert job["title"] == "Invoice.pdf"
    assert job["settings"]["copies"] == 2
    assert job["settings"]["orientation"] == "auto"  # defaults are filled in
    assert job["fallback_occurred"] is False


async def test_idempotency_key_is_required(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)

    response = await client.post(scene.url, headers=scene.headers, json=scene.print_job())

    assert response.status_code == 400
    assert response.json()["code"] == "idempotency.key_required"


async def test_same_key_and_body_returns_the_same_job(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    headers = {**scene.headers, **key()}

    first = await client.post(scene.url, headers=headers, json=scene.print_job())
    second = await client.post(scene.url, headers=headers, json=scene.print_job())

    assert first.status_code == 201
    assert "Idempotent-Replayed" not in first.headers
    assert second.status_code == 200
    assert second.headers["Idempotent-Replayed"] == "true"
    assert second.json()["id"] == first.json()["id"]
    assert await session.scalar(select(func.count()).select_from(Job)) == 1


async def test_same_key_with_a_different_body_is_rejected(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    headers = {**scene.headers, **key()}
    await client.post(scene.url, headers=headers, json=scene.print_job())

    response = await client.post(
        scene.url, headers=headers, json=scene.print_job(title="Other.pdf")
    )

    assert response.status_code == 422
    assert response.json()["code"] == "idempotency.key_reused"
    assert await session.scalar(select(func.count()).select_from(Job)) == 1


async def test_failed_request_does_not_consume_the_key(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    headers = {**scene.headers, **key()}
    bad = scene.print_job(printer_id=str(uuid.uuid4()))

    rejected = await client.post(scene.url, headers=headers, json=bad)
    # The client fixes the request and reuses the key.
    accepted = await client.post(scene.url, headers=headers, json=bad | scene.print_job())

    assert rejected.status_code == 404
    assert rejected.json()["code"] == "printer.not_found"
    assert accepted.status_code == 201


async def test_client_supplied_id_is_kept(client: httpx.AsyncClient, session: AsyncSession) -> None:
    scene = await make_scene(session)
    job_id = str(uuid.uuid7())

    job = await create_job(client, scene, id=job_id)
    clash = await client.post(
        scene.url, headers={**scene.headers, **key()}, json=scene.print_job(id=job_id)
    )

    assert job["id"] == job_id
    assert clash.status_code == 409
    assert clash.json()["code"] == "job.id_conflict"


async def test_settings_are_validated_per_job_type(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    headers = {**scene.headers, **key()}

    scan_setting_on_print = await client.post(
        scene.url, headers=headers, json=scene.print_job(settings={"resolution_dpi": 300})
    )
    bad_range = await client.post(
        scene.url, headers=headers, json=scene.print_job(settings={"page_ranges": "1-"})
    )
    scan = await client.post(
        scene.url,
        headers={**scene.headers, **key()},
        json={
            "type": "scan",
            "printer_id": str(scene.printer.id),
            "settings": {"source": "adf", "duplex": True, "resolution_dpi": 600},
        },
    )

    assert scan_setting_on_print.status_code == 422
    assert bad_range.status_code == 422
    assert scan.status_code == 201
    assert scan.json()["settings"]["format"] == "application/pdf"


async def test_job_on_a_printer_known_not_to_support_it_is_rejected(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    scene.printer.capabilities = {"schema_version": 1, "print": {"supported": True}}
    await session.flush()

    response = await client.post(
        scene.url,
        headers={**scene.headers, **key()},
        json={"type": "scan", "printer_id": str(scene.printer.id)},
    )

    assert response.status_code == 422
    assert response.json()["code"] == "job.unsupported_by_printer"


# --- Organization policy -----------------------------------------------------


async def test_max_copies_policy(client: httpx.AsyncClient, session: AsyncSession) -> None:
    scene = await make_scene(session, settings={"max_copies_per_job": 5})

    over = await client.post(
        scene.url,
        headers={**scene.headers, **key()},
        json=scene.print_job(settings={"copies": 6, "color_mode": "monochrome"}),
    )
    at_limit = await client.post(
        scene.url,
        headers={**scene.headers, **key()},
        json=scene.print_job(settings={"copies": 5, "color_mode": "monochrome"}),
    )

    assert over.status_code == 422
    assert over.json()["code"] == "job.policy_violation"
    assert at_limit.status_code == 201


async def test_color_printing_policy(client: httpx.AsyncClient, session: AsyncSession) -> None:
    scene = await make_scene(session, settings={"color_printing_roles": ["owner", "admin"]})
    user = await member_headers(session, scene.organization, Role.USER)

    color = await client.post(
        scene.url, headers={**user, **key()}, json=scene.print_job(settings={"color_mode": "color"})
    )
    auto = await client.post(
        scene.url, headers={**user, **key()}, json=scene.print_job(settings={"color_mode": "auto"})
    )
    mono = await client.post(
        scene.url,
        headers={**user, **key()},
        json=scene.print_job(settings={"color_mode": "monochrome"}),
    )
    owner_color = await client.post(
        scene.url,
        headers={**scene.headers, **key()},
        json=scene.print_job(settings={"color_mode": "color"}),
    )

    assert color.status_code == 403
    assert color.json()["code"] == "job.color_not_allowed"
    assert auto.status_code == 403
    assert mono.status_code == 201
    assert owner_color.status_code == 201


async def test_viewer_cannot_create_jobs(client: httpx.AsyncClient, session: AsyncSession) -> None:
    scene = await make_scene(session)
    viewer = await member_headers(session, scene.organization, Role.VIEWER)

    response = await client.post(scene.url, headers={**viewer, **key()}, json=scene.print_job())

    assert response.status_code == 403


# --- Reporting state ---------------------------------------------------------


async def test_reported_lifecycle(client: httpx.AsyncClient, session: AsyncSession) -> None:
    scene = await make_scene(session)
    connection = await create_connection(session, scene.printer)
    job = await create_job(client, scene, connection_id=str(connection.id))

    await report(client, scene, job["id"], status="processing", connection_id=str(connection.id))
    await report(client, scene, job["id"], status="printing", printer_job_ref="ipp-42")
    done = await report(client, scene, job["id"], status="completed", page_count=6)

    assert done.status_code == 200
    body = done.json()
    assert body["status"] == "completed"
    assert body["connection_type"] == "ipps"
    assert body["printer_job_ref"] == "ipp-42"
    assert body["page_count"] == 6
    assert body["started_at"] is not None
    assert body["completed_at"] is not None
    assert body["fallback_occurred"] is False

    events = (await client.get(f"{scene.url}/{job['id']}/events", headers=scene.headers)).json()
    assert [event["status"] for event in events] == [
        "queued",
        "processing",
        "printing",
        "completed",
    ]
    assert events[1]["connection_type"] == "ipps"
    assert events[1]["reported_by_user_id"] == str(scene.owner.id)


async def test_switching_connection_marks_fallback(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    primary = await create_connection(session, scene.printer, priority=1)
    backup = await create_connection(session, scene.printer, type="airprint", priority=2)
    job = await create_job(client, scene)

    first = await report(
        client, scene, job["id"], status="processing", connection_id=str(primary.id)
    )
    second = await report(
        client,
        scene,
        job["id"],
        status="processing",
        connection_id=str(backup.id),
        error_code="ipp.unreachable",
    )
    done = await report(client, scene, job["id"], status="completed")

    assert first.json()["fallback_occurred"] is False
    assert second.json()["fallback_occurred"] is True
    assert done.json()["connection_id"] == str(backup.id)
    assert done.json()["connection_type"] == "airprint"
    assert done.json()["fallback_occurred"] is True


async def test_failure_records_the_error(client: httpx.AsyncClient, session: AsyncSession) -> None:
    scene = await make_scene(session)
    job = await create_job(client, scene)

    response = await report(
        client,
        scene,
        job["id"],
        status="failed",
        error_code="ipp.client-error-not-possible",
        error_message="The printer rejected the selected tray.",
    )

    body = response.json()
    assert body["status"] == "failed"
    assert body["error_code"] == "ipp.client-error-not-possible"
    assert body["error_message"] == "The printer rejected the selected tray."


async def test_invalid_transitions_are_rejected(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    job = await create_job(client, scene)
    await report(client, scene, job["id"], status="printing")

    backwards = await report(client, scene, job["id"], status="processing")
    wrong_type = await report(client, scene, job["id"], status="scanning")
    await report(client, scene, job["id"], status="completed")
    after_terminal = await report(client, scene, job["id"], status="failed")

    for response in (backwards, wrong_type, after_terminal):
        assert response.status_code == 409
        assert response.json()["code"] == "job.invalid_transition"


async def test_repeating_the_final_report_is_harmless(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    job = await create_job(client, scene)
    first = await report(client, scene, job["id"], status="completed", page_count=3)

    again = await report(client, scene, job["id"], status="completed", page_count=99)

    assert again.status_code == 200
    assert again.json()["page_count"] == 3
    assert again.json()["completed_at"] == first.json()["completed_at"]
    events = (await client.get(f"{scene.url}/{job['id']}/events", headers=scene.headers)).json()
    assert [event["status"] for event in events] == ["queued", "completed"]


async def test_connection_must_belong_to_the_printer(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    other_printer = await create_printer(session, scene.organization, friendly_name="Other")
    foreign = await create_connection(session, other_printer)
    job = await create_job(client, scene)

    response = await report(
        client, scene, job["id"], status="processing", connection_id=str(foreign.id)
    )

    assert response.status_code == 404
    assert response.json()["code"] == "connection.not_found"


# --- Visibility and control --------------------------------------------------


async def test_users_see_only_their_own_jobs(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    alice = await member_headers(session, scene.organization, Role.USER)
    bob = await member_headers(session, scene.organization, Role.USER)
    operator = await member_headers(session, scene.organization, Role.OPERATOR)
    alice_job = await create_job(client, scene, headers=alice, title="Alice.pdf")
    await create_job(client, scene, headers=bob, title="Bob.pdf")

    bob_list = (await client.get(scene.url, headers=bob)).json()["items"]
    operator_list = (await client.get(scene.url, headers=operator)).json()["items"]
    bob_reads_alice = await client.get(f"{scene.url}/{alice_job['id']}", headers=bob)
    bob_filters_alice = (
        await client.get(scene.url, headers=bob, params={"user_id": alice_job["user_id"]})
    ).json()["items"]

    assert [job["title"] for job in bob_list] == ["Bob.pdf"]
    assert {job["title"] for job in operator_list} == {"Alice.pdf", "Bob.pdf"}
    assert bob_reads_alice.status_code == 404
    assert [job["title"] for job in bob_filters_alice] == ["Bob.pdf"]


async def test_only_owner_or_operator_can_change_a_job(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    alice = await member_headers(session, scene.organization, Role.USER)
    viewer = await member_headers(session, scene.organization, Role.VIEWER)
    operator = await member_headers(session, scene.organization, Role.OPERATOR)
    job = await create_job(client, scene, headers=alice)

    # A viewer can read every job but not change one.
    viewer_report = await report(client, scene, job["id"], headers=viewer, status="completed")
    viewer_cancel = await client.post(f"{scene.url}/{job['id']}/cancel", headers=viewer)
    operator_cancel = await client.post(f"{scene.url}/{job['id']}/cancel", headers=operator)

    assert viewer_report.status_code == 403
    assert viewer_cancel.status_code == 403
    assert operator_cancel.status_code == 200
    assert operator_cancel.json()["status"] == "cancelled"
    assert operator_cancel.json()["completed_at"] is not None


async def test_cancel_own_job(client: httpx.AsyncClient, session: AsyncSession) -> None:
    scene = await make_scene(session)
    job = await create_job(client, scene)

    cancelled = await client.post(f"{scene.url}/{job['id']}/cancel", headers=scene.headers)
    again = await client.post(f"{scene.url}/{job['id']}/cancel", headers=scene.headers)

    assert cancelled.json()["status"] == "cancelled"
    assert again.status_code == 200  # cancelling twice is harmless


async def test_completed_job_cannot_be_cancelled(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    job = await create_job(client, scene)
    await report(client, scene, job["id"], status="completed")

    response = await client.post(f"{scene.url}/{job['id']}/cancel", headers=scene.headers)

    assert response.status_code == 409


async def test_retry_creates_a_linked_job(client: httpx.AsyncClient, session: AsyncSession) -> None:
    scene = await make_scene(session)
    job = await create_job(client, scene)
    await report(client, scene, job["id"], status="failed", error_code="ipp.unreachable")
    headers = {**scene.headers, **key()}

    retried = await client.post(f"{scene.url}/{job['id']}/retry", headers=headers)
    replay = await client.post(f"{scene.url}/{job['id']}/retry", headers=headers)

    assert retried.status_code == 201
    new_job = retried.json()
    assert new_job["id"] != job["id"]
    assert new_job["retry_of_job_id"] == job["id"]
    assert new_job["status"] == "queued"
    assert new_job["settings"] == job["settings"]
    assert new_job["title"] == job["title"]
    assert new_job["error_code"] is None
    assert replay.status_code == 200
    assert replay.json()["id"] == new_job["id"]
    assert await session.scalar(select(func.count()).select_from(Job)) == 2
    original = (await client.get(f"{scene.url}/{job['id']}", headers=scene.headers)).json()
    assert original["status"] == "failed"


async def test_only_failed_or_cancelled_jobs_can_be_retried(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    job = await create_job(client, scene)

    response = await client.post(
        f"{scene.url}/{job['id']}/retry", headers={**scene.headers, **key()}
    )

    assert response.status_code == 409
    assert response.json()["code"] == "job.not_retryable"


# --- Listing -----------------------------------------------------------------


async def test_list_filters(client: httpx.AsyncClient, session: AsyncSession) -> None:
    scene = await make_scene(session)
    second_printer = await create_printer(session, scene.organization, friendly_name="Second")
    member = await add_member(session, scene.organization, Role.USER)
    member_auth = await auth_headers(session, member)
    yesterday = (datetime.now(UTC) - timedelta(days=1)).isoformat()

    done = await create_job(client, scene, title="Done.pdf")
    await report(client, scene, done["id"], status="completed")
    failed = await create_job(client, scene, title="Failed.pdf")
    await report(client, scene, failed["id"], status="failed")
    await create_job(client, scene, title="Old.pdf", submitted_at=yesterday)
    await create_job(client, scene, title="Second.pdf", printer_id=str(second_printer.id))
    await create_job(client, scene, headers=member_auth, title="Member.pdf")
    await client.post(
        scene.url,
        headers={**scene.headers, **key()},
        json={"type": "scan", "printer_id": str(scene.printer.id), "title": "Scan"},
    )

    async def titles(**params: Any) -> list[str]:
        response = await client.get(scene.url, headers=scene.headers, params=params)
        assert response.status_code == 200
        return [job["title"] for job in response.json()["items"]]

    assert await titles(status=["completed", "failed"]) == ["Failed.pdf", "Done.pdf"]
    assert await titles(type="scan") == ["Scan"]
    assert await titles(printer_id=str(second_printer.id)) == ["Second.pdf"]
    assert await titles(user_id=str(member.id)) == ["Member.pdf"]
    cutoff = (datetime.now(UTC) - timedelta(hours=1)).isoformat()
    assert await titles(submitted_to=cutoff) == ["Old.pdf"]
    assert "Old.pdf" not in await titles(submitted_from=cutoff)
    assert len(await titles()) == 6


async def test_jobs_are_invisible_across_organizations(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene_a = await make_scene(session, name="A")
    scene_b = await make_scene(session, name="B")
    job = await create_job(client, scene_a)

    response = await client.get(f"{scene_b.url}/{job['id']}", headers=scene_b.headers)
    cross_printer = await client.post(
        scene_b.url,
        headers={**scene_b.headers, **key()},
        json=scene_a.print_job(),
    )

    assert response.status_code == 404
    assert cross_printer.status_code == 404
    assert cross_printer.json()["code"] == "printer.not_found"
