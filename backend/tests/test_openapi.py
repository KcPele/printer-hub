import json

from scripts.export_openapi import OPENAPI_PATH, render


def test_checked_in_contract_matches_the_app() -> None:
    assert OPENAPI_PATH.read_text() == render(), (
        "openapi.json is out of date. Run `make openapi` and commit the result."
    )


def test_operation_ids_are_unique_and_readable() -> None:
    schema = json.loads(render())
    operation_ids = [
        operation["operationId"] for path in schema["paths"].values() for operation in path.values()
    ]

    assert len(operation_ids) == len(set(operation_ids))
    assert "jobs_create_job" in operation_ids
    assert "auth_login" in operation_ids


def _operations() -> list[dict[str, object]]:
    schema = json.loads(render())
    return [
        operation
        for path in schema["paths"].values()
        for operation in path.values()
        if isinstance(operation, dict)
    ]


def test_every_error_response_is_a_typed_problem() -> None:
    problem = {"application/problem+json": {"schema": {"$ref": "#/components/schemas/Problem"}}}
    checked = 0
    for operation in _operations():
        for status, response in operation["responses"].items():  # type: ignore[attr-defined]
            if status.startswith(("4", "5")) and status != "503":
                assert response["content"] == problem, (operation["operationId"], status)
                checked += 1
    assert checked > 100


def test_idempotency_key_is_required_where_it_is_enforced() -> None:
    required = {
        operation["operationId"]
        for operation in _operations()
        for parameter in operation.get("parameters", [])  # type: ignore[attr-defined]
        if parameter["name"] == "Idempotency-Key" and parameter["required"]
    }
    optional = {
        operation["operationId"]
        for operation in _operations()
        for parameter in operation.get("parameters", [])  # type: ignore[attr-defined]
        if parameter["name"] == "Idempotency-Key" and not parameter["required"]
    }

    assert required == {"jobs_create_job", "jobs_retry_job"}
    assert optional == {"documents_create_document"}


def test_replayed_creates_describe_their_body() -> None:
    by_id = {operation["operationId"]: operation for operation in _operations()}
    for operation_id in ("jobs_create_job", "jobs_retry_job", "documents_create_document"):
        replay = by_id[operation_id]["responses"]["200"]  # type: ignore[index]
        assert "application/json" in replay["content"], operation_id
