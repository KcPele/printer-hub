import httpx


async def test_live(client: httpx.AsyncClient) -> None:
    response = await client.get("/api/v1/health/live")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


async def test_ready_reports_dependencies(client: httpx.AsyncClient) -> None:
    response = await client.get("/api/v1/health/ready")

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "database": "ok", "redis": "ok"}


async def test_response_carries_request_id(client: httpx.AsyncClient) -> None:
    generated = await client.get("/api/v1/health/live")
    echoed = await client.get("/api/v1/health/live", headers={"X-Request-ID": "abc-123"})

    assert generated.headers["X-Request-ID"]
    assert echoed.headers["X-Request-ID"] == "abc-123"
