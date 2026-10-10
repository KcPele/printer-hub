import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

import httpx
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.adapters.storage.memory import MemoryStorage
from app.core.db import session_scope
from app.core.permissions import Role
from app.modules.documents import service
from app.modules.documents.models import Document
from tests.factories import member_headers
from tests.modules.test_jobs import Scene, key, make_scene

API = "/api/v1"


def _url(scene: Scene) -> str:
    return f"{API}/organizations/{scene.organization.id}/documents"


def _pdf(**overrides: Any) -> dict[str, Any]:
    body: dict[str, Any] = {
        "file_name": "Invoice 2026-10.pdf",
        "mime_type": "application/pdf",
        "size_bytes": 48_213,
        "page_count": 2,
    }
    body.update(overrides)
    return body


async def _create(
    client: httpx.AsyncClient, scene: Scene, headers: dict[str, str] | None = None, **overrides: Any
) -> dict[str, Any]:
    response = await client.post(
        _url(scene), headers=headers or scene.headers, json=_pdf(**overrides)
    )
    assert response.status_code == 201, response.text
    body: dict[str, Any] = response.json()
    return body


def _key_of(scene: Scene, document: dict[str, Any]) -> str:
    return f"organizations/{scene.organization.id}/documents/{document['id']}"


# --- Local documents ---------------------------------------------------------


async def test_local_document_stores_metadata_only(
    client: httpx.AsyncClient, session: AsyncSession, storage: MemoryStorage
) -> None:
    scene = await make_scene(session)

    document = await _create(client, scene, tags=["Finance", " invoices ", "finance"])

    assert document["storage_mode"] == "local"
    assert document["upload_status"] == "not_applicable"
    assert document["upload"] is None
    assert document["tags"] == ["finance", "invoices"]
    assert document["retention_expires_at"] is None
    download = await client.get(
        f"{_url(scene)}/{document['id']}/download-url", headers=scene.headers
    )
    assert download.status_code == 409
    assert download.json()["code"] == "document.not_cloud"
    assert storage.objects == {}


async def test_recognized_text_is_refused_for_local_documents(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)

    response = await client.post(
        _url(scene), headers=scene.headers, json=_pdf(ocr_text="Total due: 400")
    )

    assert response.status_code == 422
    assert response.json()["code"] == "document.local_content_not_accepted"


async def test_file_type_and_size_are_validated(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)

    executable = await client.post(
        _url(scene), headers=scene.headers, json=_pdf(mime_type="application/x-msdownload")
    )
    huge = await client.post(_url(scene), headers=scene.headers, json=_pdf(size_bytes=10 * 1024**3))

    assert executable.status_code == 422
    assert executable.json()["code"] == "document.unsupported_type"
    assert huge.status_code == 422
    assert huge.json()["code"] == "document.too_large"


# --- Cloud documents ---------------------------------------------------------


async def test_cloud_upload_flow(
    client: httpx.AsyncClient, session: AsyncSession, storage: MemoryStorage
) -> None:
    scene = await make_scene(session)

    document = await _create(client, scene, storage_mode="cloud")

    assert document["upload_status"] == "pending"
    upload = document["upload"]
    assert upload["method"] == "PUT"
    assert upload["headers"] == {"Content-Type": "application/pdf"}
    assert _key_of(scene, document) in upload["url"]
    # The storage key never contains the file name.
    assert "Invoice" not in upload["url"]
    base = f"{_url(scene)}/{document['id']}"

    too_early = await client.post(f"{base}/complete-upload", headers=scene.headers)
    assert too_early.status_code == 409
    assert too_early.json()["code"] == "document.upload_missing"
    not_ready = await client.get(f"{base}/download-url", headers=scene.headers)
    assert not_ready.json()["code"] == "document.upload_incomplete"

    storage.put(_key_of(scene, document), 48_213)
    completed = await client.post(f"{base}/complete-upload", headers=scene.headers)
    assert completed.status_code == 200
    assert completed.json()["upload_status"] == "uploaded"
    # Confirming twice is harmless.
    assert (await client.post(f"{base}/complete-upload", headers=scene.headers)).status_code == 200

    download = await client.get(f"{base}/download-url", headers=scene.headers)
    assert download.status_code == 200
    assert _key_of(scene, document) in download.json()["url"]
    assert download.headers["Cache-Control"] == "no-store"


async def test_upload_of_the_wrong_size_is_discarded(
    client: httpx.AsyncClient, session: AsyncSession, storage: MemoryStorage
) -> None:
    scene = await make_scene(session)
    document = await _create(client, scene, storage_mode="cloud")
    storage.put(_key_of(scene, document), 999_999)

    response = await client.post(
        f"{_url(scene)}/{document['id']}/complete-upload", headers=scene.headers
    )

    assert response.status_code == 422
    assert response.json()["code"] == "document.size_mismatch"
    assert storage.objects == {}


async def test_expired_upload_instructions_can_be_renewed(
    client: httpx.AsyncClient, session: AsyncSession, storage: MemoryStorage
) -> None:
    scene = await make_scene(session)
    document = await _create(client, scene, storage_mode="cloud")
    base = f"{_url(scene)}/{document['id']}"

    renewed = await client.get(f"{base}/upload-url", headers=scene.headers)
    storage.put(_key_of(scene, document), 48_213)
    await client.post(f"{base}/complete-upload", headers=scene.headers)
    after_upload = await client.get(f"{base}/upload-url", headers=scene.headers)

    assert renewed.status_code == 200
    assert renewed.json()["method"] == "PUT"
    assert after_upload.status_code == 409
    assert after_upload.json()["code"] == "document.upload_not_pending"


async def test_local_only_policy_blocks_cloud_documents(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session, settings={"document_storage_mode": "local_only"})

    cloud = await client.post(_url(scene), headers=scene.headers, json=_pdf(storage_mode="cloud"))
    local = await client.post(_url(scene), headers=scene.headers, json=_pdf())

    assert cloud.status_code == 403
    assert cloud.json()["code"] == "document.cloud_storage_disabled"
    assert local.status_code == 201


async def test_retention_policy_sets_expiry_on_cloud_documents(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session, settings={"document_retention_days": 7})

    cloud = await _create(client, scene, storage_mode="cloud")
    local = await _create(client, scene)

    expires = datetime.fromisoformat(cloud["retention_expires_at"])
    assert timedelta(days=6, hours=23) < expires - datetime.now(UTC) < timedelta(days=7, minutes=1)
    assert local["retention_expires_at"] is None


async def test_purge_removes_expired_documents_and_their_files(
    client: httpx.AsyncClient,
    session: AsyncSession,
    session_factory: Any,
    storage: MemoryStorage,
) -> None:
    scene = await make_scene(session, settings={"document_retention_days": 7})
    expired = await _create(client, scene, storage_mode="cloud", file_name="Old.pdf")
    kept = await _create(client, scene, storage_mode="cloud", file_name="New.pdf")
    storage.put(_key_of(scene, expired), 48_213)
    storage.put(_key_of(scene, kept), 48_213)
    await session.execute(
        update(Document)
        .where(Document.id == uuid.UUID(expired["id"]))
        .values(retention_expires_at=datetime.now(UTC) - timedelta(minutes=1))
    )

    async with session_scope(session_factory) as work:
        purged = await service.purge_expired(work)

    assert purged == 1
    assert list(storage.objects) == [_key_of(scene, kept)]
    listing = await client.get(_url(scene), headers=scene.headers)
    assert [item["file_name"] for item in listing.json()["items"]] == ["New.pdf"]


# --- Idempotency and IDs -----------------------------------------------------


async def test_create_is_idempotent_with_a_key(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    headers = {**scene.headers, **key()}

    first = await client.post(_url(scene), headers=headers, json=_pdf(storage_mode="cloud"))
    second = await client.post(_url(scene), headers=headers, json=_pdf(storage_mode="cloud"))

    assert first.status_code == 201
    assert second.status_code == 200
    assert second.headers["Idempotent-Replayed"] == "true"
    assert second.json()["id"] == first.json()["id"]
    # The replay still tells the client how to upload.
    assert second.json()["upload"] is not None
    assert await session.scalar(select(func.count()).select_from(Document)) == 1


async def test_client_supplied_id(client: httpx.AsyncClient, session: AsyncSession) -> None:
    scene = await make_scene(session)
    document_id = str(uuid.uuid7())

    created = await _create(client, scene, id=document_id)
    clash = await client.post(_url(scene), headers=scene.headers, json=_pdf(id=document_id))

    assert created["id"] == document_id
    assert clash.status_code == 409
    assert clash.json()["code"] == "document.id_conflict"


# --- Search, access, changes -------------------------------------------------


async def test_search(client: httpx.AsyncClient, session: AsyncSession) -> None:
    scene = await make_scene(session)
    await _create(client, scene, file_name="Invoice March.pdf", tags=["finance"])
    await _create(
        client,
        scene,
        file_name="Scan 0042.pdf",
        storage_mode="cloud",
        source="printer_scan",
        source_printer_id=str(scene.printer.id),
        ocr_text="Lease agreement between the parties",
    )
    await _create(client, scene, file_name="Photo_100%.jpg", mime_type="image/jpeg", tags=["trip"])

    async def names(**params: Any) -> list[str]:
        response = await client.get(_url(scene), headers=scene.headers, params=params)
        assert response.status_code == 200
        return [item["file_name"] for item in response.json()["items"]]

    assert await names(q="invoice") == ["Invoice March.pdf"]
    assert await names(q="LEASE") == ["Scan 0042.pdf"]  # recognized text
    assert await names(q="finance") == ["Invoice March.pdf"]  # tag
    assert await names(q="100%") == ["Photo_100%.jpg"]  # wildcards are literal
    assert await names(q="_") == ["Photo_100%.jpg"]
    assert await names(tag="Trip") == ["Photo_100%.jpg"]
    assert await names(mime_type="image/jpeg") == ["Photo_100%.jpg"]
    assert await names(source="printer_scan") == ["Scan 0042.pdf"]
    assert await names(source_printer_id=str(scene.printer.id)) == ["Scan 0042.pdf"]
    assert len(await names()) == 3


async def test_recognized_text_is_searchable_but_not_returned(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)

    document = await _create(client, scene, storage_mode="cloud", ocr_text="Confidential terms")

    assert document["has_ocr_text"] is True
    assert "ocr_text" not in document
    assert "Confidential" not in str(document)


async def test_documents_are_their_owners_until_shared(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    alice = await member_headers(session, scene.organization, Role.USER)
    bob = await member_headers(session, scene.organization, Role.USER)
    operator = await member_headers(session, scene.organization, Role.OPERATOR)
    admin = await member_headers(session, scene.organization, Role.ADMIN)
    document = await _create(client, scene, headers=alice)
    url = f"{_url(scene)}/{document['id']}"
    assert document["shared"] is False

    # Nobody else sees it, whatever their role.
    for other in (bob, operator, admin):
        assert (await client.get(url, headers=other)).status_code == 404
        assert (await client.get(_url(scene), headers=other)).json()["items"] == []

    shared = await client.patch(url, headers=alice, json={"shared": True})
    assert shared.json()["shared"] is True

    # Now every member sees it, but only its owner or an administrator changes it.
    assert (await client.get(url, headers=bob)).status_code == 200
    listed = (await client.get(_url(scene), headers=bob)).json()["items"]
    assert [item["id"] for item in listed] == [document["id"]]
    assert (
        await client.patch(url, headers=operator, json={"file_name": "Renamed.pdf"})
    ).status_code == 403
    assert (await client.delete(url, headers=operator)).status_code == 403
    renamed = await client.patch(url, headers=admin, json={"file_name": "Renamed.pdf"})
    assert renamed.status_code == 200
    # A change that leaves `shared` out leaves it as it was.
    assert renamed.json()["shared"] is True

    await client.patch(url, headers=alice, json={"shared": False})
    assert (await client.get(url, headers=bob)).status_code == 404


async def test_a_document_can_be_shared_from_the_start(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    bob = await member_headers(session, scene.organization, Role.USER)
    document = await _create(client, scene, shared=True)

    assert document["shared"] is True
    assert (await client.get(f"{_url(scene)}/{document['id']}", headers=bob)).status_code == 200


async def test_rename_and_retag(client: httpx.AsyncClient, session: AsyncSession) -> None:
    scene = await make_scene(session)
    document = await _create(client, scene, tags=["draft"])

    response = await client.patch(
        f"{_url(scene)}/{document['id']}",
        headers=scene.headers,
        json={"file_name": "Final.pdf", "tags": ["Signed"]},
    )

    assert response.status_code == 200
    assert response.json()["file_name"] == "Final.pdf"
    assert response.json()["tags"] == ["signed"]
    assert response.json()["page_count"] == 2


async def test_delete_removes_the_stored_file(
    client: httpx.AsyncClient, session: AsyncSession, storage: MemoryStorage
) -> None:
    scene = await make_scene(session)
    document = await _create(client, scene, storage_mode="cloud")
    storage.put(_key_of(scene, document), 48_213)
    url = f"{_url(scene)}/{document['id']}"

    response = await client.delete(url, headers=scene.headers)

    assert response.status_code == 204
    assert (await client.get(url, headers=scene.headers)).status_code == 404
    assert storage.objects == {}


async def test_job_can_reference_a_registered_document(
    client: httpx.AsyncClient, session: AsyncSession
) -> None:
    scene = await make_scene(session)
    document = await _create(client, scene)

    linked = await client.post(
        scene.url,
        headers={**scene.headers, **key()},
        json=scene.print_job(document_id=document["id"]),
    )
    unknown = await client.post(
        scene.url,
        headers={**scene.headers, **key()},
        json=scene.print_job(document_id=str(uuid.uuid4())),
    )

    assert linked.status_code == 201
    assert linked.json()["document_id"] == document["id"]
    assert unknown.status_code == 404
    assert unknown.json()["code"] == "document.not_found"


async def test_scan_job_links_its_output_document(
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
    scan = await _create(
        client, scene, source="printer_scan", source_printer_id=str(scene.printer.id)
    )

    response = await client.post(
        f"{scene.url}/{job['id']}/events",
        headers=scene.headers,
        json={"status": "completed", "output_document_id": scan["id"], "page_count": 2},
    )

    assert response.status_code == 200
    assert response.json()["output_document_id"] == scan["id"]
