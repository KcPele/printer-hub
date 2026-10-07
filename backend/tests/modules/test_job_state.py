import pytest

from app.core.errors import ConflictError
from app.modules.jobs.models import JobStatus as S
from app.modules.jobs.models import JobType as T
from app.modules.jobs.state import is_stale, validate_transition


@pytest.mark.parametrize(
    ("job_type", "current", "new"),
    [
        (T.PRINT, S.QUEUED, S.PROCESSING),
        (T.PRINT, S.PROCESSING, S.PRINTING),
        (T.PRINT, S.PRINTING, S.COMPLETED),
        (T.PRINT, S.QUEUED, S.COMPLETED),  # offline client reports only the outcome
        (T.PRINT, S.QUEUED, S.CANCELLED),
        (T.PRINT, S.PRINTING, S.FAILED),
        (T.PRINT, S.PROCESSING, S.PROCESSING),  # another attempt on a fallback connection
        (T.SCAN, S.PROCESSING, S.SCANNING),
        (T.SCAN, S.SCANNING, S.COMPLETED),
        (T.COPY, S.SCANNING, S.PRINTING),
        (T.COPY, S.PRINTING, S.COMPLETED),
    ],
)
def test_allowed_transitions(job_type: T, current: S, new: S) -> None:
    validate_transition(job_type, current, new)


@pytest.mark.parametrize(
    ("job_type", "current", "new"),
    [
        (T.PRINT, S.PRINTING, S.PROCESSING),
        (T.PRINT, S.PROCESSING, S.QUEUED),
        (T.COPY, S.PRINTING, S.SCANNING),
        (T.PRINT, S.COMPLETED, S.PRINTING),
        (T.PRINT, S.COMPLETED, S.FAILED),
        (T.PRINT, S.FAILED, S.COMPLETED),
        (T.PRINT, S.CANCELLED, S.QUEUED),
        (T.PRINT, S.PROCESSING, S.SCANNING),  # a print job never scans
        (T.SCAN, S.PROCESSING, S.PRINTING),  # a scan job never prints
    ],
)
def test_rejected_transitions(job_type: T, current: S, new: S) -> None:
    with pytest.raises(ConflictError) as error:
        validate_transition(job_type, current, new)

    assert error.value.code == "job.invalid_transition"


def test_staleness() -> None:
    assert is_stale(S.PRINTING, S.PROCESSING)
    assert is_stale(S.COMPLETED, S.PRINTING)
    assert is_stale(S.COMPLETED, S.FAILED)
    assert not is_stale(S.PROCESSING, S.PRINTING)
    assert not is_stale(S.PROCESSING, S.PROCESSING)
