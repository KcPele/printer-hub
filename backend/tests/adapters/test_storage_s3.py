"""Round trip against the MinIO container from docker-compose.yml."""

import uuid

import httpx
import pytest

from app.adapters.storage.s3 import S3Storage

pytestmark = pytest.mark.integration


@pytest.fixture
async def s3() -> S3Storage:
    storage = S3Storage(
        bucket="printerhub-test",
        region="us-east-1",
        access_key="printerhub",
        secret_key="printerhub-dev-secret",
        endpoint_url="http://localhost:9000",
    )
    await storage.ensure_bucket()
    return storage


async def test_presigned_upload_and_download_round_trip(s3: S3Storage) -> None:
    key = f"tests/{uuid.uuid4()}"
    content = b"%PDF-1.7 pretend document"
    assert await s3.stat(key) is None

    upload = s3.presign_upload(key, content_type="application/pdf", expires_in=60)
    async with httpx.AsyncClient() as http:
        put = await http.request(upload.method, upload.url, headers=upload.headers, content=content)
        assert put.status_code == 200

        info = await s3.stat(key)
        assert info is not None
        assert info.size_bytes == len(content)

        link = s3.presign_download(key, file_name='Invoice "final".pdf', expires_in=60)
        got = await http.get(link)
        assert got.content == content
        assert got.headers["content-disposition"] == 'attachment; filename="Invoice final.pdf"'
        # Stored encrypted at rest by the bucket's default encryption.
        assert got.headers.get("x-amz-server-side-encryption") == "AES256"

        await s3.delete(key)
        assert await s3.stat(key) is None
        assert (await http.get(link)).status_code == 404
        await s3.delete(key)  # deleting again is not an error


async def test_upload_with_a_different_content_type_is_refused(s3: S3Storage) -> None:
    upload = s3.presign_upload(
        f"tests/{uuid.uuid4()}", content_type="application/pdf", expires_in=60
    )

    async with httpx.AsyncClient() as http:
        response = await http.put(upload.url, headers={"Content-Type": "text/html"}, content=b"x")

    assert response.status_code == 403
