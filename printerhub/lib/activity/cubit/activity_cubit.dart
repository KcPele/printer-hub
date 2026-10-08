import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:jobs_repository/jobs_repository.dart';

enum ActivityStatus { loading, ready, failed }

/// Which jobs the history is narrowed to.
enum ActivityFilter {
  all([]),
  active(['queued', 'processing', 'scanning', 'printing']),
  done(['completed']),
  problems(['failed', 'cancelled']);

  new(this.statuses);

  /// The job statuses it lets through. None means every one.
  final List<String> statuses;

  bool admits(Job job) => statuses.isEmpty || statuses.contains(job.status);
}

class ActivityState extends Equatable {
  const new({
    this.status = ActivityStatus.loading,
    this.filter = ActivityFilter.all,
    this.waiting = const [],
    this.jobs = const [],
    this.next,
    this.loadingMore = false,
    this.error,
  });

  final ActivityStatus status;
  final ActivityFilter filter;

  /// The jobs that are only on this phone so far, newest first.
  final List<Job> waiting;

  /// The jobs the workspace has, newest first, as far as they were read.
  final List<Job> jobs;

  /// Where the next page starts. Null when there is no more.
  final String? next;
  final bool loadingMore;

  /// Why the history could not be read. Pass it to `errorMessage`.
  final ApiException? error;

  /// Everything to list: what is waiting on the phone, then the rest.
  List<Job> get visible => [
    for (final job in waiting)
      if (filter.admits(job)) job,
    ...jobs,
  ];

  @override
  List<Object?> get props => [
    status,
    filter,
    waiting,
    jobs,
    next,
    loadingMore,
    error,
  ];
}

/// The history of what was printed and scanned in one workspace.
///
/// Reading it is also when the phone sends what it recorded while the API
/// was out of reach. It reads again by itself when a job begins or ends.
class ActivityCubit extends Cubit<ActivityState> {
  new({required this._jobsRepository, required this._organizationId})
    : super(const ActivityState()) {
    _changes = _jobsRepository.changes.listen((_) => unawaited(refresh()));
  }

  final JobsRepository _jobsRepository;
  final String _organizationId;
  late final StreamSubscription<void> _changes;

  /// Counts the reads begun, so an answer that was overtaken is dropped.
  int _reads = 0;
  bool _syncing = false;

  /// Reads the history from the start, showing that it is being read.
  Future<void> load() {
    emit(ActivityState(filter: state.filter));
    return _read();
  }

  /// Reads the history again, leaving what is shown until it has.
  Future<void> refresh() => _read();

  /// Narrows the history to [filter].
  Future<void> show(ActivityFilter filter) {
    emit(ActivityState(filter: filter));
    return _read();
  }

  /// Reads the next page.
  Future<void> more() async {
    final cursor = state.next;
    if (cursor == null || state.loadingMore) return;
    final read = _reads;
    emit(_with(loadingMore: true));
    try {
      final page = await _list(cursor: cursor);
      if (read != _reads || isClosed) return;
      emit(_with(jobs: [...state.jobs, ...page.jobs], next: () => page.next));
    } on ApiException catch (error) {
      if (read != _reads || isClosed) return;
      emit(_with(error: error));
    }
  }

  Future<void> _read() async {
    final read = ++_reads;
    final filter = state.filter;
    await _send();
    final waiting = await _jobsRepository.waiting(_organizationId);
    try {
      final page = await _list();
      if (read != _reads || isClosed) return;
      emit(
        ActivityState(
          status: ActivityStatus.ready,
          filter: filter,
          waiting: waiting,
          jobs: page.jobs,
          next: page.next,
        ),
      );
    } on ApiException catch (error) {
      if (read != _reads || isClosed) return;
      emit(
        ActivityState(
          // What is on the phone is still worth showing.
          status: waiting.isEmpty && state.jobs.isEmpty
              ? ActivityStatus.failed
              : ActivityStatus.ready,
          filter: filter,
          waiting: waiting,
          jobs: state.jobs,
          next: state.next,
          error: error,
        ),
      );
    }
  }

  /// Sends what the phone recorded while the API was out of reach.
  Future<void> _send() async {
    // Sending tells this cubit the history changed, which reads it again.
    if (_syncing) return;
    _syncing = true;
    try {
      await _jobsRepository.sync(_organizationId);
    } on ApiException {
      // Reading the history says what is wrong.
    } finally {
      _syncing = false;
    }
  }

  Future<({List<Job> jobs, String? next})> _list({String? cursor}) {
    return _jobsRepository.list(
      organizationId: _organizationId,
      statuses: state.filter.statuses,
      cursor: cursor,
    );
  }

  ActivityState _with({
    List<Job>? jobs,
    String? Function()? next,
    bool loadingMore = false,
    ApiException? error,
  }) {
    return ActivityState(
      status: state.status,
      filter: state.filter,
      waiting: state.waiting,
      jobs: jobs ?? state.jobs,
      next: next == null ? state.next : next(),
      loadingMore: loadingMore,
      error: error,
    );
  }

  @override
  Future<void> close() async {
    await _changes.cancel();
    await super.close();
  }
}
