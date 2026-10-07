"""S3-compatible storage (AWS S3, MinIO, and similar)."""

from typing import Any

import boto3
from anyio import to_thread
from botocore.config import Config
from botocore.exceptions import ClientError

from app.adapters.storage.base import ObjectInfo, PresignedUpload


class S3Storage:
    def __init__(
        self,
        *,
        bucket: str,
        region: str,
        access_key: str,
        secret_key: str,
        endpoint_url: str | None = None,
        public_endpoint_url: str | None = None,
    ) -> None:
        self._bucket = bucket
        self._region = region
        self._client = self._make_client(endpoint_url, region, access_key, secret_key)
        # Presigned URLs embed the host, so they are signed for the address
        # clients use, which can differ from the one the backend uses.
        self._presign_client = (
            self._make_client(public_endpoint_url, region, access_key, secret_key)
            if public_endpoint_url
            else self._client
        )

    @staticmethod
    def _make_client(
        endpoint_url: str | None, region: str, access_key: str, secret_key: str
    ) -> Any:
        return boto3.client(
            "s3",
            endpoint_url=endpoint_url,
            region_name=region,
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            # Path-style addressing works with MinIO and with AWS.
            config=Config(signature_version="s3v4", s3={"addressing_style": "path"}),
        )

    def presign_upload(self, key: str, *, content_type: str, expires_in: int) -> PresignedUpload:
        url: str = self._presign_client.generate_presigned_url(
            "put_object",
            Params={"Bucket": self._bucket, "Key": key, "ContentType": content_type},
            ExpiresIn=expires_in,
        )
        return PresignedUpload(url=url, headers={"Content-Type": content_type})

    def presign_download(self, key: str, *, file_name: str, expires_in: int) -> str:
        safe_name = file_name.replace('"', "").replace("\\", "")
        url: str = self._presign_client.generate_presigned_url(
            "get_object",
            Params={
                "Bucket": self._bucket,
                "Key": key,
                "ResponseContentDisposition": f'attachment; filename="{safe_name}"',
            },
            ExpiresIn=expires_in,
        )
        return url

    async def stat(self, key: str) -> ObjectInfo | None:
        def head() -> ObjectInfo | None:
            try:
                response = self._client.head_object(Bucket=self._bucket, Key=key)
            except ClientError as error:
                if error.response["Error"]["Code"] in ("404", "NoSuchKey", "NotFound"):
                    return None
                raise
            return ObjectInfo(size_bytes=int(response["ContentLength"]))

        return await to_thread.run_sync(head)

    async def delete(self, key: str) -> None:
        await to_thread.run_sync(lambda: self._client.delete_object(Bucket=self._bucket, Key=key))

    async def ensure_bucket(self) -> None:
        """Create the bucket with default encryption at rest. For local development.

        In production the bucket is provisioned by infrastructure, with
        default encryption turned on.
        """

        def ensure() -> None:
            try:
                self._client.head_bucket(Bucket=self._bucket)
            except ClientError:
                self._client.create_bucket(Bucket=self._bucket)
            self._client.put_bucket_encryption(
                Bucket=self._bucket,
                ServerSideEncryptionConfiguration={
                    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
                },
            )

        await to_thread.run_sync(ensure)
