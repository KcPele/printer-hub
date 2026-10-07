"""Writes one sample response per job type from backend/openapi.json.

The samples feed test/src/contract_test.dart, which checks that the generated
Dart models decode what the contract describes. Run after the job schemas
change:  python3 tool/make_fixtures.py
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT.parents[2] / "backend" / "openapi.json"
SCHEMAS = json.loads(CONTRACT.read_text())["components"]["schemas"]


def sample(schema: dict) -> object:
    if "$ref" in schema:
        return sample(SCHEMAS[schema["$ref"].rsplit("/", 1)[-1]])
    if "const" in schema:
        return schema["const"]
    if "enum" in schema:
        return schema["enum"][0]
    if "anyOf" in schema:
        options = schema["anyOf"]
        if any(option.get("type") == "null" for option in options):
            return None
        return sample(options[0])
    kind = schema.get("type")
    if kind == "object":
        return {name: sample(prop) for name, prop in schema.get("properties", {}).items()}
    if kind == "array":
        return []
    if kind == "string":
        if schema.get("format") == "date-time":
            return "2026-10-07T10:00:00Z"
        if schema.get("format") == "uuid":
            return "0198c0de-0000-7000-8000-00000000000a"
        return "sample"
    if kind == "integer":
        return max(1, schema.get("minimum", 1))
    if kind == "number":
        return 1.0
    if kind == "boolean":
        return False
    raise ValueError(f"No sample for {schema}")


for name in ("PrintJobRead", "ScanJobRead", "CopyJobRead"):
    target = ROOT / "test" / "fixtures" / f"{name}.json"
    target.write_text(json.dumps(sample(SCHEMAS[name]), indent=2) + "\n")
    print(f"Wrote {target.relative_to(ROOT)}")
