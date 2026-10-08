import 'dart:async';
import 'dart:convert';

import 'package:api_client/api_client.dart';
import 'package:jobs_repository/src/models.dart';
import 'package:local_store/local_store.dart';

/// Keeps the record of jobs: tells the backend when one starts and how it
/// goes, and holds on to what it could not send.
///
/// The phone runs a job against the printer whether or not the API can be
/// reached, so starting a job and reporting on it never fail for being
/// offline. What was not sent waits in an outbox and goes with the next
/// [sync]. Every job carries its own identifier and idempotency key, so
/// sending it twice changes nothing.
class JobsRepository {
  new({required this._client, required this._store, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final PrinterHubClient _client;
  final SecureStore _store;
  final DateTime Function() _now;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Fires when the history is no longer what it was: a job began or
  /// ended, or what was waiting has been sent.
  Stream<void> get changes => _changes.stream;

  static String _outboxKey(String organizationId) =>
      'jobs.outbox.$organizationId';

  static String _runningKey(String organizationId) =>
      'jobs.running.$organizationId';

  /// The jobs this run of the app started and has not seen the end of.
  /// A job that is running elsewhere in the app is not one that was
  /// interrupted.
  final Set<String> _live = {};

  /// Records a print the phone is about to run, and returns the job.
  ///
  /// [connectionId] is the connection it will try first.
  Future<Job> startPrint({
    required String organizationId,
    required String printerId,
    required PrintChoices choices,
    String? title,
    int? pageCount,
    String? connectionId,
  }) {
    final now = _now().toUtc();
    final create = JobCreatePrintJobCreate(
      // The history is listed by identifier, so it begins with the time.
      id: newRecordId(now),
      type: 'print',
      printerId: printerId,
      executionMode: ExecutionMode.local,
      title: title,
      documentId: null,
      connectionId: connectionId,
      pageCount: pageCount,
      submittedAt: now,
      settings: choices.toApi(),
    );
    return _start(organizationId, create);
  }

  /// Records a scan the phone is about to run, and returns the job.
  Future<Job> startScan({
    required String organizationId,
    required String printerId,
    required ScanChoices choices,
    String? title,
    String? connectionId,
  }) {
    final now = _now().toUtc();
    final create = JobCreateScanJobCreate(
      id: newRecordId(now),
      type: 'scan',
      printerId: printerId,
      executionMode: ExecutionMode.local,
      title: title,
      documentId: null,
      connectionId: connectionId,
      pageCount: null,
      submittedAt: now,
      settings: choices.toApi(),
    );
    return _start(organizationId, create);
  }

  /// Keeps a new job to be sent, and sends it if the API can be reached.
  Future<Job> _start(String organizationId, JobCreate create) async {
    final entry = _Entry(
      key: newIdempotencyKey(),
      job: _plain(create.toJson()),
    );

    final outbox = await _read(organizationId);
    outbox.add(entry);
    await _write(organizationId, outbox);

    try {
      final recorded = await apiCall(
        () => _client.api.jobs.createJob(
          orgId: organizationId,
          idempotencyKey: entry.key,
          body: create,
        ),
      );
      // The backend has it: nothing is left to send.
      outbox.remove(entry);
      await _write(organizationId, outbox);
      final job = Job.fromApi(recorded);
      await _track(organizationId, job);
      _changes.add(null);
      return job;
    } on ApiUnreachable {
      final job = entry.asJob();
      await _track(organizationId, job);
      _changes.add(null);
      return job;
    } on ApiProblem {
      // The backend will not have this job. It is not kept to be sent
      // again, and the caller is told why.
      outbox.remove(entry);
      await _write(organizationId, outbox);
      rethrow;
    }
  }

  /// Records a change in a running job. Never throws: a change that cannot
  /// be sent now is kept, and one the backend refuses is dropped, since a
  /// record must not stop a document from printing.
  Future<void> report(
    String organizationId,
    String jobId,
    JobUpdate update,
  ) async {
    final event = update.toApi(_now().toUtc());
    final ended = Job.finished.contains(update.status);
    try {
      await _report(organizationId, jobId, event);
    } finally {
      if (ended) {
        await _untrack(organizationId, jobId);
        _changes.add(null);
      } else if (update.printerJobRef != null) {
        await _noteOnPrinter(organizationId, jobId, update.printerJobRef!);
      }
    }
  }

  /// The jobs this phone started and never saw the end of, because the
  /// app was closed while they ran. Oldest first.
  ///
  /// Each is still to be settled: ask the printer what became of it, and
  /// [report] the answer, which takes it off this list.
  Future<List<RunningJob>> interrupted(String organizationId) async {
    return [
      for (final job in await _readRunning(organizationId))
        if (!_live.contains(job.jobId)) job,
    ];
  }

  Future<void> _track(String organizationId, Job job) async {
    _live.add(job.id);
    await _writeRunning(organizationId, [
      ...await _readRunning(organizationId),
      RunningJob(
        jobId: job.id,
        printerId: job.printerId,
        kind: job.kind,
        title: job.title,
        startedAt: _now().toUtc(),
      ),
    ]);
  }

  Future<void> _untrack(String organizationId, String jobId) async {
    _live.remove(jobId);
    final running = await _readRunning(organizationId);
    if (running.every((job) => job.jobId != jobId)) return;
    await _writeRunning(organizationId, [
      for (final job in running)
        if (job.jobId != jobId) job,
    ]);
  }

  /// Keeps the printer's own number for a job, by which it is asked about
  /// later.
  Future<void> _noteOnPrinter(
    String organizationId,
    String jobId,
    String printerJobRef,
  ) async {
    await _writeRunning(organizationId, [
      for (final job in await _readRunning(organizationId))
        if (job.jobId == jobId) job.onPrinterAs(printerJobRef) else job,
    ]);
  }

  Future<List<RunningJob>> _readRunning(String organizationId) async {
    final json = await _store.read(_runningKey(organizationId));
    if (json == null) return [];
    try {
      return [
        for (final item in jsonDecode(json) as List<dynamic>)
          RunningJob.fromJson(item as Map<String, dynamic>),
      ];
    } on Object {
      // Written by an older version of the app.
      return [];
    }
  }

  Future<void> _writeRunning(String organizationId, List<RunningJob> running) {
    return _store.write(
      _runningKey(organizationId),
      jsonEncode([for (final job in running) job.toJson()]),
    );
  }

  Future<void> _report(
    String organizationId,
    String jobId,
    JobEventCreate event,
  ) async {
    final outbox = await _read(organizationId);
    final entry = outbox.where((entry) => entry.id == jobId).firstOrNull;

    // Changes are sent in the order they happened, so a job that is
    // waiting, or has changes waiting, holds back the ones after.
    if (entry != null) {
      entry.events.add(_plain(event.toJson()));
      await _write(organizationId, outbox);
      return;
    }
    try {
      await apiCall(
        () => _client.api.jobs.reportJobEvent(
          orgId: organizationId,
          jobId: jobId,
          body: event,
        ),
      );
    } on ApiUnreachable {
      outbox.add(
        _Entry(
          key: newIdempotencyKey(),
          job: {'id': jobId},
          events: [_plain(event.toJson())],
          registered: true,
        ),
      );
      await _write(organizationId, outbox);
    } on ApiProblem {
      // Refused: the job is already past this point on the backend.
    }
  }

  /// Sends what was recorded while the API was out of reach. Returns how
  /// many jobs are still waiting, which is none when everything went.
  Future<int> sync(String organizationId) async {
    final outbox = await _read(organizationId);
    if (outbox.isEmpty) return 0;

    try {
      final unregistered = [
        for (final entry in outbox)
          if (!entry.registered) entry,
      ];
      if (unregistered.isNotEmpty) {
        final response = await apiCall(
          () => _client.api.jobs.syncJobs(
            orgId: organizationId,
            body: JobSyncRequest(
              items: [
                for (final entry in unregistered)
                  JobSyncItem(
                    idempotencyKey: entry.key,
                    job: JobCreate.fromJson(entry.job),
                    events: [
                      for (final event in entry.events)
                        JobEventCreate.fromJson(event),
                    ],
                  ),
              ],
            ),
          ),
        );
        // Created, replayed, or refused for good: none is sent again.
        final answered = {
          for (final result in response.results) result.idempotencyKey,
        };
        for (final entry in unregistered) {
          if (!answered.contains(entry.key)) continue;
          entry
            ..registered = true
            ..events.clear();
        }
      }

      for (final entry in outbox) {
        while (entry.registered && entry.events.isNotEmpty) {
          try {
            await apiCall(
              () => _client.api.jobs.reportJobEvent(
                orgId: organizationId,
                jobId: entry.id,
                body: JobEventCreate.fromJson(entry.events.first),
              ),
            );
          } on ApiProblem {
            // Refused for good. The ones after it may still be accepted.
          }
          entry.events.removeAt(0);
        }
      }
    } on ApiUnreachable {
      // Still out of reach. What went is not sent again.
    }

    // A job that is on the backend with nothing waiting is done with.
    final before = outbox.length;
    outbox.removeWhere((entry) => entry.registered && entry.events.isEmpty);
    await _write(organizationId, outbox);
    if (outbox.length != before) _changes.add(null);
    return outbox.length;
  }

  /// The jobs the backend has not been told about yet, newest first.
  Future<List<Job>> waiting(String organizationId) async {
    final outbox = await _read(organizationId);
    return [
      for (final entry in outbox.reversed)
        if (!entry.registered) entry.asJob(),
    ];
  }

  /// A page of the job history, newest first. Pass [cursor] from the page
  /// before to read on.
  Future<({List<Job> jobs, String? next})> list({
    required String organizationId,
    String? printerId,
    String? kind,
    List<String> statuses = const [],
    String? cursor,
  }) async {
    final page = await apiCall(
      () => _client.api.jobs.listJobs(
        orgId: organizationId,
        printerId: printerId,
        type: kind == null ? null : JobType.fromJson(kind),
        status: statuses.isEmpty
            ? null
            : [for (final status in statuses) JobStatus.fromJson(status)],
        cursor: cursor,
      ),
    );
    return (jobs: page.items.map(Job.fromApi).toList(), next: page.nextCursor);
  }

  Future<Job> get({
    required String organizationId,
    required String jobId,
  }) async {
    return Job.fromApi(
      await apiCall(
        () => _client.api.jobs.getJob(orgId: organizationId, jobId: jobId),
      ),
    );
  }

  /// What happened to a job, in order.
  Future<List<JobEvent>> events({
    required String organizationId,
    required String jobId,
  }) async {
    final events = await apiCall(
      () => _client.api.jobs.listJobEvents(orgId: organizationId, jobId: jobId),
    );
    return events.map(JobEvent.fromApi).toList();
  }

  /// Marks a job cancelled. Stopping it on the printer is the caller's
  /// part.
  Future<Job> cancel({
    required String organizationId,
    required String jobId,
  }) async {
    final job = Job.fromApi(
      await apiCall(
        () => _client.api.jobs.cancelJob(orgId: organizationId, jobId: jobId),
      ),
    );
    await _untrack(organizationId, jobId);
    _changes.add(null);
    return job;
  }

  /// Records a new job with the settings of one that failed or was
  /// cancelled. Running it is the caller's part.
  Future<Job> retry({
    required String organizationId,
    required String jobId,
  }) async {
    final job = Job.fromApi(
      await apiCall(
        () => _client.api.jobs.retryJob(
          orgId: organizationId,
          jobId: jobId,
          idempotencyKey: newIdempotencyKey(),
        ),
      ),
    );
    // It is about to be run, like a job that was just started.
    await _track(organizationId, job);
    _changes.add(null);
    return job;
  }

  /// Forgets what is waiting. Call when the user signs out.
  Future<void> clear(Iterable<String> organizationIds) async {
    for (final id in organizationIds) {
      await _store.delete(_outboxKey(id));
      await _store.delete(_runningKey(id));
    }
    _live.clear();
  }

  /// A copy made of nothing but JSON values, as it will be once it has
  /// been written and read back.
  static Map<String, dynamic> _plain(Map<String, Object?> json) {
    return jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
  }

  Future<List<_Entry>> _read(String organizationId) async {
    final json = await _store.read(_outboxKey(organizationId));
    if (json == null) return [];
    try {
      return [
        for (final item in jsonDecode(json) as List<dynamic>)
          _Entry.fromJson(item as Map<String, dynamic>),
      ];
    } on Object {
      // Written by an older version of the app.
      return [];
    }
  }

  Future<void> _write(String organizationId, List<_Entry> outbox) {
    return _store.write(
      _outboxKey(organizationId),
      jsonEncode([for (final entry in outbox) entry.toJson()]),
    );
  }
}

/// A job in the outbox: what is yet to be sent about it.
class _Entry {
  new({
    required this.key,
    required this.job,
    List<Map<String, dynamic>>? events,
    this.registered = false,
  }) : events = events ?? [];

  factory fromJson(Map<String, dynamic> json) {
    return _Entry(
      key: json['key'] as String,
      job: json['job'] as Map<String, dynamic>,
      events: (json['events'] as List<dynamic>).cast<Map<String, dynamic>>(),
      registered: json['registered'] as bool,
    );
  }

  /// The idempotency key the job is created with, every time.
  final String key;

  /// The job as it is sent to be created. For a job the backend already
  /// has, only its `id`.
  final Map<String, dynamic> job;

  /// The changes not yet sent, oldest first.
  final List<Map<String, dynamic>> events;

  /// True once the backend has the job.
  bool registered;

  String get id => job['id'] as String;

  /// Where the job has got to, by the last change recorded here.
  String get status =>
      events.isEmpty ? 'queued' : events.last['status'] as String;

  Job asJob() {
    return Job.fromJson({...job, 'status': status}, waitingToSync: true);
  }

  Map<String, Object?> toJson() => {
    'key': key,
    'job': job,
    'events': events,
    'registered': registered,
  };
}
