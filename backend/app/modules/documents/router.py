import uuid
from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Header, Query, Response, status

from app.core.deps import SessionDep
from app.core.errors import problem_responses
from app.core.idempotency import IDEMPOTENCY_HEADER, REPLAYED_HEADER
from app.core.pagination import Page, PageParams
from app.core.permissions import Permission
from app.modules.documents import service
from app.modules.documents.models import Document, DocumentSource
from app.modules.documents.schemas import (
    DocumentCreate,
    DocumentCreated,
    DocumentRead,
    DocumentUpdate,
    DownloadLink,
    UploadInstructions,
)
from app.modules.documents.service import DocumentFilters
from app.modules.organizations.deps import OrgContext, require

router = APIRouter(prefix="/organizations/{org_id}/documents", tags=["documents"])

Member = Annotated[OrgContext, Depends(require(Permission.ORG_READ))]
Creator = Annotated[OrgContext, Depends(require(Permission.DOCUMENTS_CREATE))]


def _created(document: Document) -> DocumentCreated:
    upload = service.upload_instructions(document)
    return DocumentCreated(
        **service.to_read(document).model_dump(),
        upload=(
            UploadInstructions(
                url=upload[0].url,
                method=upload[0].method,
                headers=upload[0].headers,
                expires_at=upload[1],
            )
            if upload
            else None
        ),
    )


@router.post(
    "",
    status_code=status.HTTP_201_CREATED,
    responses={
        status.HTTP_200_OK: {
            "model": DocumentCreated,
            "description": "Replay of an earlier request with this key",
        },
        **problem_responses(409),
    },
)
async def create_document(
    payload: DocumentCreate,
    ctx: Creator,
    session: SessionDep,
    response: Response,
    idempotency_key: Annotated[
        str | None, Header(alias=IDEMPOTENCY_HEADER, min_length=1, max_length=255)
    ] = None,
) -> DocumentCreated:
    """Register a document.

    A `local` document records metadata only; its bytes stay on the device.
    A `cloud` document returns upload instructions: send the bytes to that
    URL, then call `complete-upload`.
    """
    document, replayed = await service.create(
        session, ctx, payload=payload, idempotency_key=idempotency_key
    )
    if replayed:
        response.status_code = status.HTTP_200_OK
        response.headers[REPLAYED_HEADER] = "true"
    return _created(document)


@router.get("")
async def list_documents(
    ctx: Member,
    session: SessionDep,
    params: Annotated[PageParams, Depends()],
    q: Annotated[
        str | None,
        Query(max_length=200, description="Matches file name, recognized text, or a tag"),
    ] = None,
    tag: Annotated[str | None, Query(max_length=50)] = None,
    mime_type: str | None = None,
    source: DocumentSource | None = None,
    source_printer_id: uuid.UUID | None = None,
    created_from: datetime | None = None,
    created_to: datetime | None = None,
) -> Page[DocumentRead]:
    """Documents, newest first. Members without `documents.read_all` see only their own."""
    documents, next_cursor = await service.list_documents(
        session,
        ctx,
        params=params,
        filters=DocumentFilters(
            query=q,
            tag=tag,
            mime_type=mime_type,
            source=source,
            source_printer_id=source_printer_id,
            created_from=created_from,
            created_to=created_to,
        ),
    )
    return Page(
        items=[service.to_read(document) for document in documents], next_cursor=next_cursor
    )


@router.get("/{document_id}")
async def get_document(document_id: uuid.UUID, ctx: Member, session: SessionDep) -> DocumentRead:
    return service.to_read(await service.get(session, ctx, document_id))


@router.patch("/{document_id}")
async def update_document(
    document_id: uuid.UUID, payload: DocumentUpdate, ctx: Member, session: SessionDep
) -> DocumentRead:
    document = await service.get(session, ctx, document_id)
    return service.to_read(await service.update(session, ctx, document, payload))


@router.delete("/{document_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_document(document_id: uuid.UUID, ctx: Member, session: SessionDep) -> None:
    """Delete the document and, for a cloud document, its stored file."""
    document = await service.get(session, ctx, document_id)
    await service.delete(session, ctx, document)


@router.post("/{document_id}/complete-upload", responses=problem_responses(409))
async def complete_upload(document_id: uuid.UUID, ctx: Member, session: SessionDep) -> DocumentRead:
    """Confirm the upload finished. The stored file's size is checked against the declared one."""
    document = await service.get(session, ctx, document_id)
    return service.to_read(await service.complete_upload(session, ctx, document))


@router.get("/{document_id}/upload-url", responses=problem_responses(409))
async def get_upload_url(
    document_id: uuid.UUID, ctx: Member, session: SessionDep
) -> UploadInstructions:
    """Fresh upload instructions, for when the first ones expired before the upload finished."""
    document = await service.get(session, ctx, document_id)
    presigned, expires_at = service.refresh_upload(ctx, document)
    return UploadInstructions(
        url=presigned.url, method=presigned.method, headers=presigned.headers, expires_at=expires_at
    )


@router.get("/{document_id}/download-url", responses=problem_responses(409))
async def get_download_url(
    document_id: uuid.UUID, ctx: Member, session: SessionDep, response: Response
) -> DownloadLink:
    """A short-lived link to the stored file of a cloud document."""
    document = await service.get(session, ctx, document_id)
    url, expires_at = service.download_link(document)
    response.headers["Cache-Control"] = "no-store"
    return DownloadLink(url=url, expires_at=expires_at)
