"""Write the API contract to openapi.json.

    python -m scripts.export_openapi

Clients generate their types from this file. CI fails when it is out of date.
"""

import json
from pathlib import Path
from typing import Any

from app.main import create_app

OPENAPI_PATH = Path(__file__).resolve().parent.parent / "openapi.json"


def render() -> str:
    schema: dict[str, Any] = create_app().openapi()
    return json.dumps(schema, indent=2, sort_keys=True) + "\n"


if __name__ == "__main__":
    OPENAPI_PATH.write_text(render())
    print(f"Wrote {OPENAPI_PATH}")
