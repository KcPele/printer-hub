"""Application factory."""

import asyncio
import os
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager, suppress
from typing import Any, cast

import structlog
from arq.worker import create_worker
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.routing import APIRoute

from app.api import api_router
from app.core.config import get_settings
from app.core.db import get_engine
from app.core.errors import PROBLEM_CONTENT_TYPE, register_exception_handlers
from app.core.idempotency import IDEMPOTENCY_HEADER, REQUIRED_KEY_DESCRIPTION
from app.core.logging import REQUEST_ID_HEADER, RequestContextMiddleware, configure_logging
from app.core.redis import get_redis


def _operation_id(route: APIRoute) -> str:
    """The endpoint function's name, which generated clients use as the method name.

    Clients group methods by tag, so `list_jobs` reads as `jobs.listJobs`.
    Function names are therefore unique across the API; a test checks it.
    """
    return route.name


def _shared_suffix(names: list[str]) -> str:
    """`PrintJobCreate`, `ScanJobCreate`, `CopyJobCreate` share `JobCreate`."""
    reversed_prefix = os.path.commonprefix([name[::-1] for name in names])
    suffix = reversed_prefix[::-1]
    while suffix and not suffix[0].isupper():
        suffix = suffix[1:]
    return suffix


def _name_request_unions(schema: dict[str, Any]) -> None:
    """Give a request body that is one of several models a name of its own.

    FastAPI writes such a body inline, so a generated client invents a
    different type for each endpoint that takes it. Responses already refer to
    a named union (`JobRead`); this does the same for bodies (`JobCreate`).
    """
    components: dict[str, Any] = schema.setdefault("components", {}).setdefault("schemas", {})
    for path_item in schema.get("paths", {}).values():
        for operation in path_item.values():
            if not isinstance(operation, dict):
                continue
            for media in operation.get("requestBody", {}).get("content", {}).values():
                body = media.get("schema", {})
                if "oneOf" not in body:
                    continue
                members = [member["$ref"].rsplit("/", 1)[-1] for member in body["oneOf"]]
                name = _shared_suffix(members)
                union = {key: body[key] for key in ("oneOf", "discriminator") if key in body}
                if components.setdefault(name, union) != union:
                    raise RuntimeError(f"Request body union {members} collides with schema {name}")
                media["schema"] = {"$ref": f"#/components/schemas/{name}"}


log = structlog.get_logger(__name__)


def _log_worker_exit(task: asyncio.Task[None]) -> None:
    if not task.cancelled() and task.exception() is not None:
        log.error("embedded_worker_stopped", exc_info=task.exception())


@asynccontextmanager
async def _lifespan(_: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    worker = None
    worker_task: asyncio.Task[None] | None = None
    if settings.embedded_worker and settings.tasks_backend == "arq":
        # Imported here: the worker module builds its Redis settings on import.
        from app.worker import WorkerSettings

        # With several API processes each runs a worker. That is safe: a queued
        # task goes to one of them, and arq runs each scheduled job once.
        worker = create_worker(cast("Any", WorkerSettings), handle_signals=False)
        worker_task = asyncio.create_task(worker.async_run())
        worker_task.add_done_callback(_log_worker_exit)
    yield
    if worker is not None and worker_task is not None:
        await worker.close()
        with suppress(asyncio.CancelledError):
            await worker_task
    await get_engine().dispose()
    await get_redis().aclose()


def _polish_contract(schema: dict[str, Any]) -> None:
    """Make the published OpenAPI document say what the API actually does.

    Generated clients take their types from this document, so the places
    where FastAPI's output is looser than the behavior are tightened:

    - Error responses are `application/problem+json` bodies shaped like
      `Problem`. FastAPI also lists `application/json`, which leaves a
      generated client unable to tell what an error body is.
    - `Idempotency-Key` is required where a missing one is rejected. It is
      read as optional so that the rejection can carry a specific error code.
    - A request body that is one of several models is a named schema.
    """
    _name_request_unions(schema)
    problem = {"schema": {"$ref": "#/components/schemas/Problem"}}
    for path_item in schema.get("paths", {}).values():
        for operation in path_item.values():
            if not isinstance(operation, dict):
                continue
            for response in operation.get("responses", {}).values():
                if PROBLEM_CONTENT_TYPE in response.get("content", {}):
                    response["content"] = {PROBLEM_CONTENT_TYPE: problem}
            for parameter in operation.get("parameters", []):
                if (
                    parameter.get("name") == IDEMPOTENCY_HEADER
                    and parameter.get("description") == REQUIRED_KEY_DESCRIPTION
                ):
                    parameter["required"] = True
                    parameter["schema"] = {"type": "string", "minLength": 1, "maxLength": 255}


def create_app() -> FastAPI:
    settings = get_settings()
    configure_logging()

    app = FastAPI(
        title="PrinterHub API",
        version="0.1.0",
        description=(
            "Shared backend for PrinterHub mobile and web clients. "
            "Clients execute print and scan jobs on the local network and report state here."
        ),
        lifespan=_lifespan,
        generate_unique_id_function=_operation_id,
        docs_url="/api/docs",
        redoc_url=None,
        openapi_url="/api/openapi.json",
    )

    app.add_middleware(RequestContextMiddleware)
    if settings.cors_origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=settings.cors_origins,
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
            expose_headers=[REQUEST_ID_HEADER, "Idempotent-Replayed", "Retry-After"],
        )

    register_exception_handlers(app)
    app.include_router(api_router)

    generate_openapi = app.openapi

    def openapi() -> dict[str, Any]:
        if app.openapi_schema is None:
            _polish_contract(generate_openapi())
        return cast("dict[str, Any]", app.openapi_schema)

    app.openapi = openapi  # type: ignore[method-assign]
    return app


app = create_app()
