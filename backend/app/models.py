"""Imports every model module so `Base.metadata` is complete.

Alembic and the test harness import this module. Add each new module's models here.
"""

from app.core.db import Base

__all__ = ["Base"]
