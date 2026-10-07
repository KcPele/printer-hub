"""The job state machine (FR-PRN-019).

    queued → processing → scanning → printing → completed | failed | cancelled

A job only moves forward, and may skip states: a client that was offline
reports where the job ended up, not every step. Terminal states are final;
a retry is a new job.
"""

from app.core.errors import ConflictError
from app.modules.jobs.models import JobStatus, JobType

TERMINAL = frozenset({JobStatus.COMPLETED, JobStatus.FAILED, JobStatus.CANCELLED})

_RANK = {
    JobStatus.QUEUED: 0,
    JobStatus.PROCESSING: 1,
    JobStatus.SCANNING: 2,
    JobStatus.PRINTING: 3,
    JobStatus.COMPLETED: 4,
    JobStatus.FAILED: 4,
    JobStatus.CANCELLED: 4,
}

# A copy scans and then prints; print and scan jobs each use one working state.
_WORKING_STATES = {
    JobType.PRINT: frozenset({JobStatus.PRINTING}),
    JobType.SCAN: frozenset({JobStatus.SCANNING}),
    JobType.COPY: frozenset({JobStatus.SCANNING, JobStatus.PRINTING}),
}
_ALWAYS_ALLOWED = frozenset({JobStatus.QUEUED, JobStatus.PROCESSING}) | TERMINAL


def is_terminal(status: JobStatus) -> bool:
    return status in TERMINAL


def is_stale(current: JobStatus, new: JobStatus) -> bool:
    """True when `new` describes a point the job has already passed or reached."""
    if current in TERMINAL:
        return True
    return _RANK[new] < _RANK[current]


def validate_transition(job_type: JobType, current: JobStatus, new: JobStatus) -> None:
    """Raise unless a `job_type` job may move from `current` to `new`.

    Reporting the current non-terminal status again is allowed: it carries a
    progress update or a new connection attempt.
    """
    if new not in _ALWAYS_ALLOWED and new not in _WORKING_STATES[job_type]:
        raise ConflictError(
            "job.invalid_transition", f"A {job_type.value} job cannot enter '{new.value}'."
        )
    if current in TERMINAL:
        raise ConflictError(
            "job.invalid_transition",
            f"The job is already {current.value} and cannot change. Retry it to run it again.",
        )
    if _RANK[new] < _RANK[current]:
        raise ConflictError(
            "job.invalid_transition",
            f"A job cannot move from '{current.value}' back to '{new.value}'.",
        )
