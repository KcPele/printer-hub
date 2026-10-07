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
