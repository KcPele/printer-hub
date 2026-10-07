from dataclasses import dataclass, field

from app.adapters.storage.base import ObjectInfo, PresignedUpload


@dataclass
class MemoryStorage:
    """Keeps object sizes in a dict. Used by tests."""

    objects: dict[str, int] = field(default_factory=dict)

    def presign_upload(self, key: str, *, content_type: str, expires_in: int) -> PresignedUpload:
        return PresignedUpload(
            url=f"memory://upload/{key}?expires_in={expires_in}",
            headers={"Content-Type": content_type},
        )

    def presign_download(self, key: str, *, file_name: str, expires_in: int) -> str:
        return f"memory://download/{key}?file_name={file_name}&expires_in={expires_in}"

    async def stat(self, key: str) -> ObjectInfo | None:
        size = self.objects.get(key)
        return ObjectInfo(size_bytes=size) if size is not None else None

    async def delete(self, key: str) -> None:
        self.objects.pop(key, None)

    def put(self, key: str, size_bytes: int) -> None:
        """Simulate a client finishing an upload."""
        self.objects[key] = size_bytes
