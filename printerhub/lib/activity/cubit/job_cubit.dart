import 'package:api_client/api_client.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:jobs_repository/jobs_repository.dart';

enum JobLoadStatus { loading, ready, failed }

class JobState extends Equatable {
  const new({
    this.status = JobLoadStatus.loading,
    this.job,
    this.events = const [],
    this.error,
    this.cancelling = false,
    this.cancelled = false,
  });

  final JobLoadStatus status;
  final Job? job;

  /// What happened to it, oldest first.
  final List<JobEvent> events;

  /// Why the job could not be read, or could not be marked cancelled. Pass
  /// it to `errorMessage`.
  final ApiException? error;
  final bool cancelling;

  /// True just after the job was marked cancelled here.
  final bool cancelled;

  @override
  List<Object?> get props => [
    status,
    job,
    events,
    error,
    cancelling,
    cancelled,
  ];
}

/// One job: what was asked for and what happened to it.
class JobCubit extends Cubit<JobState> {
  new({
    required this._jobsRepository,
    required this._organizationId,
    required this._jobId,
    Job? known,
  }) : super(
         // A job that is only on the phone is all there is to know of it.
         known != null && known.waitingToSync
             ? JobState(status: JobLoadStatus.ready, job: known)
             : JobState(job: known),
       );

  final JobsRepository _jobsRepository;
  final String _organizationId;
  final String _jobId;

  Future<void> load() async {
    if (state.job?.waitingToSync ?? false) return;
    emit(JobState(job: state.job));
    try {
      final job = await _jobsRepository.get(
        organizationId: _organizationId,
        jobId: _jobId,
      );
      final events = await _jobsRepository.events(
        organizationId: _organizationId,
        jobId: _jobId,
      );
      emit(JobState(status: JobLoadStatus.ready, job: job, events: events));
    } on ApiException catch (error) {
      emit(
        JobState(status: JobLoadStatus.failed, job: state.job, error: error),
      );
    }
  }

  /// Marks a job that will not finish as cancelled.
  Future<void> cancel() async {
    final job = state.job;
    if (job == null ||
        job.isFinished ||
        job.waitingToSync ||
        state.cancelling) {
      return;
    }
    emit(
      JobState(
        status: state.status,
        job: job,
        events: state.events,
        cancelling: true,
      ),
    );
    try {
      final cancelled = await _jobsRepository.cancel(
        organizationId: _organizationId,
        jobId: _jobId,
      );
      final events = await _jobsRepository.events(
        organizationId: _organizationId,
        jobId: _jobId,
      );
      emit(
        JobState(
          status: JobLoadStatus.ready,
          job: cancelled,
          events: events,
          cancelled: true,
        ),
      );
    } on ApiException catch (error) {
      emit(
        JobState(
          status: state.status,
          job: job,
          events: state.events,
          error: error,
        ),
      );
    }
  }
}
