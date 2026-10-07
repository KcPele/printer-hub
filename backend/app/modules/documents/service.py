"""Document metadata and optional cloud storage (FRD §14, §37)."""

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from sqlalchemy import or_, select
from sqlalchemy import update as sql_update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.adapters.storage import get_object_storage
from app.adapters.storage.base import PresignedUpload
from app.core import idempotency, tasks
from app.core.config import get_settings
from app.core.db import after_commit
from app.core.errors import (
    ConflictError,
    NotFoundError,
    PermissionDeniedError,
    ValidationFailedError,
)
from app.core.pagination import PageParams, paginate
from app.core.permissions import Permission
from app.modules.documents.models import Document, DocumentSource, StorageMode, UploadStatus
from app.modules.documents.schemas import (
    ALLOWED_MIME_TYPES,
    DocumentCreate,
    DocumentRead,
    DocumentUpdate,
)
from app.modules.organizations.context import OrgContext
from app.modules.printers import service as printers


@dataclass(frozen=True, slots=True)
class DocumentFilters:
    """FR-DOC-002."""

    query: str | None = None
    tag: str | None = None
    mime_type: str | None = None
    source: DocumentSource | None = None
    source_printer_id: uuid.UUID | None = None
    created_from: datetime | None = None
    created_to: datetime | None = None


def to_read(document: Document) -> DocumentRead:
    return DocumentRead.model_validate(
        {
            **{column.key: getattr(document, column.key) for column in Document.__table__.columns},
            "has_ocr_text": bool(document.ocr_text),
        }
    )


def _storage_key(organization_id: uuid.UUID, document_id: uuid.UUID) -> str:
    # The key holds no file name: names can carry personal data and odd characters.
    return f"organizations/{organization_id}/documents/{document_id}"


def _escape_like(value: str) -> str:
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


# --- Access ------------------------------------------------------------------


def _may_read(ctx: OrgContext, document: Document) -> bool:
    return document.owner_id == ctx.user.id or ctx.has(Permission.DOCUMENTS_READ_ALL)


def _ensure_may_change(ctx: OrgContext, document: Document) -> None:
    if document.owner_id != ctx.user.id and not ctx.has(Permission.DOCUMENTS_MANAGE_ALL):
        raise PermissionDeniedError(
            "permission.denied",
            "Only the document's owner or an administrator can change this document.",
        )


async def get(session: AsyncSession, ctx: OrgContext, document_id: uuid.UUID) -> Document:
    document = await session.scalar(
        select(Document).where(
            Document.id == document_id,
            Document.organization_id == ctx.organization.id,
            Document.deleted_at.is_(None),
        )
    )
    if document is None or not _may_read(ctx, document):
        raise NotFoundError("document.not_found", "Document not found.")
    return document


async def list_documents(
    session: AsyncSession, ctx: OrgContext, *, params: PageParams, filters: DocumentFilters
) -> tuple[list[Document], str | None]:
    stmt = select(Document).where(
        Document.organization_id == ctx.organization.id, Document.deleted_at.is_(None)
    )
    if not ctx.has(Permission.DOCUMENTS_READ_ALL):
        stmt = stmt.where(Document.owner_id == ctx.user.id)
    if filters.query:
        term = filters.query.strip()
        pattern = f"%{_escape_like(term)}%"
        stmt = stmt.where(
            or_(
                Document.file_name.ilike(pattern, escape="\\"),
                Document.ocr_text.ilike(pattern, escape="\\"),
                Document.tags.contains([term.lower()]),
            )
        )
    if filters.tag:
        stmt = stmt.where(Document.tags.contains([filters.tag.strip().lower()]))
    if filters.mime_type:
        stmt = stmt.where(Document.mime_type == filters.mime_type)
    if filters.source is not None:
        stmt = stmt.where(Document.source == filters.source)
    if filters.source_printer_id is not None:
        stmt = stmt.where(Document.source_printer_id == filters.source_printer_id)
    if filters.created_from is not None:
        stmt = stmt.where(Document.created_at >= filters.created_from)
    if filters.created_to is not None:
        stmt = stmt.where(Document.created_at < filters.created_to)
    return await paginate(session, stmt, Document.id, params)


# --- Create ------------------------------------------------------------------


def _validate_new(ctx: OrgContext, payload: DocumentCreate) -> None:
    settings = get_settings()
    if payload.mime_type not in ALLOWED_MIME_TYPES:
        raise ValidationFailedError(
            "document.unsupported_type", f"Files of type {payload.mime_type} are not supported."
        )
    if payload.size_bytes > settings.max_document_size_bytes:
        limit_mb = settings.max_document_size_bytes // (1024 * 1024)
        raise ValidationFailedError("document.too_large", f"Files can be at most {limit_mb} MB.")
    if payload.storage_mode is StorageMode.CLOUD:
        if ctx.settings.document_storage_mode == "local_only":
            raise PermissionDeniedError(
                "document.cloud_storage_disabled",
                "This organization keeps documents on devices only.",
            )
    elif payload.ocr_text is not None:
        raise ValidationFailedError(
            "document.local_content_not_accepted",
            "Recognized text can only be stored for cloud documents.",
        )


async def create(
    session: AsyncSession,
    ctx: OrgContext,
    *,
    payload: DocumentCreate,
    idempotency_key: str | None = None,
) -> tuple[Document, bool]:
    """Register a document, or return the one an earlier request with this key created."""
    scope = f"documents.create:{ctx.organization.id}"
    if idempotency_key is not None:
        existing_id = await idempotency.claim(
            session,
            user_id=ctx.user.id,
            scope=scope,
            key=idempotency_key,
            request_hash=idempotency.fingerprint(payload),
        )
        if existing_id is not None:
            return await get(session, ctx, existing_id), True

    _validate_new(ctx, payload)
    if payload.source_printer_id is not None:
        await printers.get(
            session, organization_id=ctx.organization.id, printer_id=payload.source_printer_id
        )

    is_cloud = payload.storage_mode is StorageMode.CLOUD
    retention_days = ctx.settings.document_retention_days
    document = Document(
        organization_id=ctx.organization.id,
        owner_id=ctx.user.id,
        file_name=payload.file_name,
        mime_type=payload.mime_type,
        size_bytes=payload.size_bytes,
        page_count=payload.page_count,
        source=payload.source,
        storage_mode=payload.storage_mode,
        upload_status=UploadStatus.PENDING if is_cloud else UploadStatus.NOT_APPLICABLE,
        checksum_sha256=payload.checksum_sha256,
        tags=payload.tags,
        ocr_text=payload.ocr_text,
        source_printer_id=payload.source_printer_id,
        retention_expires_at=(
            datetime.now(UTC) + timedelta(days=retention_days)
            if is_cloud and retention_days is not None
            else None
        ),
    )
    if payload.id is not None:
        document.id = payload.id
    else:
        document.id = uuid.uuid7()
    if is_cloud:
        document.storage_key = _storage_key(ctx.organization.id, document.id)
    session.add(document)
    try:
        await session.flush()
    except IntegrityError as exc:
        raise ConflictError(
            "document.id_conflict", "A document with this ID already exists."
        ) from exc

    if idempotency_key is not None:
        await idempotency.complete(
            session,
            user_id=ctx.user.id,
            scope=scope,
            key=idempotency_key,
            resource_id=document.id,
        )
    return document, False


# --- Cloud storage -----------------------------------------------------------


def upload_instructions(document: Document) -> tuple[PresignedUpload, datetime] | None:
    """A presigned upload for a cloud document that has no bytes yet."""
    if document.storage_key is None or document.upload_status is not UploadStatus.PENDING:
        return None
    ttl = get_settings().s3_presign_ttl_seconds
    presigned = get_object_storage().presign_upload(
        document.storage_key, content_type=document.mime_type, expires_in=ttl
    )
    return presigned, datetime.now(UTC) + timedelta(seconds=ttl)


def refresh_upload(ctx: OrgContext, document: Document) -> tuple[PresignedUpload, datetime]:
    """New upload instructions for a document whose first ones expired."""
    _ensure_may_change(ctx, document)
    upload = upload_instructions(document)
    if upload is None:
        raise ConflictError("document.upload_not_pending", "This document is not awaiting upload.")
    return upload


async def complete_upload(session: AsyncSession, ctx: OrgContext, document: Document) -> Document:
    """Confirm the client finished uploading, after checking the stored object."""
    _ensure_may_change(ctx, document)
    if document.storage_key is None:
        raise ConflictError("document.not_cloud", "This document is stored on the device.")
    if document.upload_status is UploadStatus.UPLOADED:
        return document

    storage = get_object_storage()
    stored = await storage.stat(document.storage_key)
    if stored is None:
        raise ConflictError(
            "document.upload_missing", "No uploaded file was found. Upload it, then try again."
        )
    if stored.size_bytes != document.size_bytes:
        await storage.delete(document.storage_key)
        raise ValidationFailedError(
            "document.size_mismatch",
            f"The uploaded file is {stored.size_bytes} bytes; {document.size_bytes} were declared.",
        )
    document.upload_status = UploadStatus.UPLOADED
    await session.flush()
    return document


def download_link(document: Document) -> tuple[str, datetime]:
    if document.storage_key is None:
        raise ConflictError(
            "document.not_cloud",
            "This document is stored on the device that created it, not in the cloud.",
        )
    if document.upload_status is not UploadStatus.UPLOADED:
        raise ConflictError("document.upload_incomplete", "This document is still uploading.")
    ttl = get_settings().s3_presign_ttl_seconds
    url = get_object_storage().presign_download(
        document.storage_key, file_name=document.file_name, expires_in=ttl
    )
    return url, datetime.now(UTC) + timedelta(seconds=ttl)


# --- Update and delete -------------------------------------------------------


async def update(
    session: AsyncSession, ctx: OrgContext, document: Document, payload: DocumentUpdate
) -> Document:
    _ensure_may_change(ctx, document)
    changes = payload.model_dump(exclude_unset=True)
    if changes.get("ocr_text") is not None and document.storage_mode is StorageMode.LOCAL:
        raise ValidationFailedError(
            "document.local_content_not_accepted",
            "Recognized text can only be stored for cloud documents.",
        )
    for name, value in changes.items():
        setattr(document, name, value)
    await session.flush()
    return document


def _delete_object_after_commit(session: AsyncSession, storage_key: str | None) -> None:
    if storage_key is None:
        return

    async def delete_object() -> None:
        await get_object_storage().delete(storage_key)

    after_commit(session, delete_object)


async def delete(session: AsyncSession, ctx: OrgContext, document: Document) -> None:
    _ensure_may_change(ctx, document)
    document.deleted_at = datetime.now(UTC)
    await session.flush()
    _delete_object_after_commit(session, document.storage_key)


DELETE_OBJECTS_TASK = "delete_stored_objects"
_KEYS_PER_TASK = 500


def _queue_object_deletion(session: AsyncSession, keys: list[str]) -> None:
    for start in range(0, len(keys), _KEYS_PER_TASK):
        tasks.enqueue(session, DELETE_OBJECTS_TASK, keys=keys[start : start + _KEYS_PER_TASK])


async def release_organization_storage(session: AsyncSession, organization_id: uuid.UUID) -> None:
    """Queue deletion of every stored file of an organization that is about to be deleted.

    The rows go with the organization by cascade; the files would otherwise
    stay in the bucket with nothing pointing at them.
    """
    keys = await session.scalars(
        select(Document.storage_key).where(
            Document.organization_id == organization_id,
            Document.storage_key.is_not(None),
            Document.deleted_at.is_(None),
        )
    )
    _queue_object_deletion(session, [key for key in keys if key is not None])


async def delete_all_owned_by(session: AsyncSession, owner_id: uuid.UUID) -> int:
    """Delete every document a user owns, in every organization. Returns how many."""
    owned = (
        await session.execute(
            select(Document.id, Document.storage_key).where(
                Document.owner_id == owner_id, Document.deleted_at.is_(None)
            )
        )
    ).all()
    if not owned:
        return 0
    await session.execute(
        sql_update(Document)
        .where(Document.id.in_([document_id for document_id, _ in owned]))
        .values(deleted_at=datetime.now(UTC), ocr_text=None)
    )
    _queue_object_deletion(session, [key for _, key in owned if key is not None])
    return len(owned)


async def purge_expired(session: AsyncSession, *, batch_size: int = 200) -> int:
    """Delete documents past their retention time (FR-DOC-008). Returns how many."""
    now = datetime.now(UTC)
    expired = list(
        await session.scalars(
            select(Document)
            .where(Document.retention_expires_at <= now, Document.deleted_at.is_(None))
            .limit(batch_size)
            .with_for_update(skip_locked=True)
        )
    )
    for document in expired:
        document.deleted_at = now
        _delete_object_after_commit(session, document.storage_key)
    await session.flush()
    return len(expired)
