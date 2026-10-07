import httpx
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.permissions import Role
from tests.factories import member_headers
from tests.modules.test_jobs import Scene, create_job, key, make_scene, report

API = "/api/v1"


async def _audit(client: httpx.AsyncClient, scene: Scene, **params: str) -> list[dict[str, object]]:
    response = await client.get(
        f"{API}/organizations/{scene.organization.id}/audit-logs",
        headers=scene.headers,
        params={"target_type": "job", **params},
    )
    assert response.status_code == 200
    items: list[dict[str, object]] = response.json()["items"]
    return items


async def test_print_submission_and_completion_are_audited(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    job = await create_job(client, scene)
    await report(client, scene, job["id"], status="printing")
    await report(client, scene, job["id"], status="completed")

    entries = await _audit(client, scene, target_id=job["id"])

    assert [entry["action"] for entry in entries] == ["job.completed", "job.submitted"]
    submitted = entries[1]
    assert submitted["actor_user_id"] == str(scene.owner.id)
    assert submitted["detail"] == {"type": "print", "printer_id": str(scene.printer.id)}


async def test_received_scan_is_audited_with_its_document(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    org_url = f"{API}/organizations/{scene.organization.id}"
    job = (
        await client.post(
            scene.url,
            headers={**scene.headers, **key()},
            json={"type": "scan", "printer_id": str(scene.printer.id)},
        )
    ).json()
    scan = (
        await client.post(
            f"{org_url}/documents",
            headers=scene.headers,
            json={
                "file_name": "Scan.pdf",
                "mime_type": "application/pdf",
                "size_bytes": 10,
                "source": "printer_scan",
            },
        )
    ).json()

    await report(client, scene, job["id"], status="completed", output_document_id=scan["id"])

    [received] = await _audit(client, scene, action="job.completed")
    assert received["detail"] == {
        "type": "scan",
        "printer_id": str(scene.printer.id),
        "output_document_id": scan["id"],
    }


async def test_cancellation_records_who_cancelled(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    member = await member_headers(session, scene.organization, Role.USER)
    job = await create_job(client, scene, headers=member)

    await client.post(f"{scene.url}/{job['id']}/cancel", headers=scene.headers)

    [cancelled] = await _audit(client, scene, action="job.cancelled")
    assert cancelled["target_id"] == job["id"]
    # The administrator who cancelled, not the member who owned the job.
    assert cancelled["actor_user_id"] == str(scene.owner.id)


async def test_failure_and_retry_are_audited(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    job = await create_job(client, scene)
    await report(client, scene, job["id"], status="failed", error_code="ipp.unreachable")
    retried = (
        await client.post(f"{scene.url}/{job['id']}/retry", headers={**scene.headers, **key()})
    ).json()

    [failed] = await _audit(client, scene, action="job.failed")
    [resubmitted] = await _audit(client, scene, action="job.submitted", target_id=retried["id"])

    assert failed["detail"]["error_code"] == "ipp.unreachable"  # type: ignore[index]
    assert resubmitted["detail"]["retry_of_job_id"] == job["id"]  # type: ignore[index]


async def test_replayed_request_is_audited_once(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    headers = {**scene.headers, **key()}
    await client.post(scene.url, headers=headers, json=scene.print_job())
    await client.post(scene.url, headers=headers, json=scene.print_job())
    job_id = (await client.get(scene.url, headers=scene.headers)).json()["items"][0]["id"]
    await report(client, scene, job_id, status="completed")
    await report(client, scene, job_id, status="completed")

    entries = await _audit(client, scene)

    assert sorted(str(entry["action"]) for entry in entries) == ["job.completed", "job.submitted"]
