"""Base class for every model that appears in the API contract."""

from pydantic import BaseModel, ConfigDict


class ApiModel(BaseModel):
    """A request or response shape.

    A field with a default is optional in a request and always present in a
    response. This setting makes the published contract say so: models used
    in both directions get separate `-Input` and `-Output` schemas, and
    generated clients type them accordingly.
    """

    model_config = ConfigDict(json_schema_serialization_defaults_required=True)
