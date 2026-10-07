import httpx
from fastapi import FastAPI
from pydantic import BaseModel

from app.core.errors import ConflictError, register_exception_handlers


class _Body(BaseModel):
    copies: int


def _app() -> FastAPI:
    app = FastAPI()
    register_exception_handlers(app)

    @app.get("/conflict")
    async def conflict() -> None:
        raise ConflictError("thing.already_exists", "That thing already exists.")

    @app.post("/validate")
    async def validate(body: _Body) -> _Body:
        return body

    @app.get("/boom")
    async def boom() -> None:
        raise RuntimeError("database password is hunter2")

    return app


async def _request(method: str, path: str, **kwargs: object) -> httpx.Response:
    transport = httpx.ASGITransport(app=_app(), raise_app_exceptions=False)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        return await client.request(method, path, **kwargs)  # type: ignore[arg-type]


async def test_app_error_renders_problem_json() -> None:
    response = await _request("GET", "/conflict")

    assert response.status_code == 409
    assert response.headers["content-type"] == "application/problem+json"
    assert response.json() == {
        "type": "about:blank",
        "title": "Conflict",
        "status": 409,
        "code": "thing.already_exists",
        "detail": "That thing already exists.",
    }


async def test_validation_error_lists_fields() -> None:
    response = await _request("POST", "/validate", json={"copies": "many"})

    body = response.json()
    assert response.status_code == 422
    assert body["code"] == "request.validation_failed"
    assert body["errors"][0]["field"] == "body.copies"


async def test_unknown_route_is_problem_json() -> None:
    response = await _request("GET", "/missing")

    assert response.status_code == 404
    assert response.json()["code"] == "http.404"


async def test_unexpected_error_hides_internals() -> None:
    response = await _request("GET", "/boom")

    assert response.status_code == 500
    assert response.json()["code"] == "internal_error"
    assert "hunter2" not in response.text
