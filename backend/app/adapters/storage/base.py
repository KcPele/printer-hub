from dataclasses import dataclass, field
from typing import Protocol


@dataclass(frozen=True, slots=True)
class PresignedUpload:
    """An upload the client performs directly against object storage."""

    url: str
    method: str = "PUT"
    # Headers the client must send unchanged, or the signature will not match.
    headers: dict[str, str] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class ObjectInfo:
    size_bytes: int


class ObjectStorage(Protocol):
    """S3-style object storage. Document bytes never pass through the API (FRD §6.1)."""

    def presign_upload(self, key: str, *, content_type: str, expires_in: int) -> PresignedUpload:
        """A time-limited request that stores one object at `key`."""
        ...

    def presign_download(self, key: str, *, file_name: str, expires_in: int) -> str:
        """A time-limited URL that downloads the object as `file_name`."""
        ...

    async def stat(self, key: str) -> ObjectInfo | None:
        """Facts about the object at `key`, or None when nothing is stored there."""
        ...

    async def delete(self, key: str) -> None:
        """Remove the object. Removing a missing object is not an error."""
        ...
