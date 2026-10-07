"""Application errors and their RFC 9457 `application/problem+json` rendering.

Every error carries a stable machine-readable `code` (for example
`job.invalid_transition`). Clients map codes to user-facing text, so a code is
part of the API contract: add new ones freely, never repurpose an existing one.
"""

from typing import Any

import structlog
from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from starlette.exceptions import HTTPException as StarletteHTTPException

log = structlog.get_logger(__name__)

PROBLEM_CONTENT_TYPE = "application/problem+json"


class FieldError(BaseModel):
    field: str
    message: str
    code: str


class Problem(BaseModel):
    """Error response body (RFC 9457)."""

    type: str = "about:blank"
    title: str
    status: int
    code: str
    detail: str | None = None
    request_id: str | None = None
    errors: list[FieldError] | None = None


class AppError(Exception):
    status_code: int = status.HTTP_500_INTERNAL_SERVER_ERROR
    title: str = "Internal Server Error"

    def __init__(
        self,
        code: str,
        detail: str | None = None,
        *,
        errors: list[FieldError] | None = None,
        headers: dict[str, str] | None = None,
    ) -> None:
        super().__init__(detail or code)
        self.code = code
        self.detail = detail
        self.errors = errors
        self.headers = headers


class BadRequestError(AppError):
    status_code = status.HTTP_400_BAD_REQUEST
    title = "Bad Request"


class UnauthorizedError(AppError):
    status_code = status.HTTP_401_UNAUTHORIZED
    title = "Unauthorized"

    def __init__(self, code: str = "auth.unauthorized", detail: str | None = None) -> None:
        super().__init__(code, detail, headers={"WWW-Authenticate": "Bearer"})


class PermissionDeniedError(AppError):
    status_code = status.HTTP_403_FORBIDDEN
    title = "Forbidden"


class NotFoundError(AppError):
    status_code = status.HTTP_404_NOT_FOUND
    title = "Not Found"


class ConflictError(AppError):
    status_code = status.HTTP_409_CONFLICT
    title = "Conflict"


class ValidationFailedError(AppError):
    status_code = status.HTTP_422_UNPROCESSABLE_CONTENT
    title = "Unprocessable Content"


class RateLimitedError(AppError):
    status_code = status.HTTP_429_TOO_MANY_REQUESTS
    title = "Too Many Requests"

    def __init__(self, retry_after_seconds: int) -> None:
        super().__init__(
            "rate_limited",
            f"Too many attempts. Try again in {retry_after_seconds} seconds.",
            headers={"Retry-After": str(retry_after_seconds)},
        )


def _request_id() -> str | None:
    value = structlog.contextvars.get_contextvars().get("request_id")
    return str(value) if value is not None else None


def _problem_response(
    *,
    status_code: int,
    title: str,
    code: str,
    detail: str | None = None,
    errors: list[FieldError] | None = None,
    headers: dict[str, str] | None = None,
) -> JSONResponse:
    problem = Problem(
        title=title,
        status=status_code,
        code=code,
        detail=detail,
        request_id=_request_id(),
        errors=errors,
    )
    return JSONResponse(
        problem.model_dump(exclude_none=True),
        status_code=status_code,
        media_type=PROBLEM_CONTENT_TYPE,
        headers=headers,
    )


async def _handle_app_error(_: Request, exc: Exception) -> JSONResponse:
    assert isinstance(exc, AppError)  # noqa: S101
    return _problem_response(
        status_code=exc.status_code,
        title=exc.title,
        code=exc.code,
        detail=exc.detail,
        errors=exc.errors,
        headers=exc.headers,
    )


async def _handle_validation_error(_: Request, exc: Exception) -> JSONResponse:
    assert isinstance(exc, RequestValidationError)  # noqa: S101
    errors = [
        FieldError(
            field=".".join(str(part) for part in error["loc"]),
            message=error["msg"],
            code=error["type"],
        )
        for error in exc.errors()
    ]
    return _problem_response(
        status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
        title="Unprocessable Content",
        code="request.validation_failed",
        detail="The request did not match the expected shape.",
        errors=errors,
    )


async def _handle_http_exception(_: Request, exc: Exception) -> JSONResponse:
    assert isinstance(exc, StarletteHTTPException)  # noqa: S101
    return _problem_response(
        status_code=exc.status_code,
        title=str(exc.detail),
        code=f"http.{exc.status_code}",
        headers=dict(exc.headers) if exc.headers else None,
    )


async def _handle_unexpected_error(_: Request, exc: Exception) -> JSONResponse:
    log.exception("unhandled_exception", exc_info=exc)
    return _problem_response(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        title="Internal Server Error",
        code="internal_error",
    )


def register_exception_handlers(app: FastAPI) -> None:
    app.add_exception_handler(AppError, _handle_app_error)
    app.add_exception_handler(RequestValidationError, _handle_validation_error)
    app.add_exception_handler(StarletteHTTPException, _handle_http_exception)
    app.add_exception_handler(Exception, _handle_unexpected_error)


def problem_responses(*status_codes: int) -> dict[int | str, dict[str, Any]]:
    """OpenAPI `responses` entries documenting problem+json bodies."""
    return {
        code: {"model": Problem, "content": {PROBLEM_CONTENT_TYPE: {}}} for code in status_codes
    }
