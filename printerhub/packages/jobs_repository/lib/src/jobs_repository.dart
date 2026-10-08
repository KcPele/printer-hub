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

  static String _outboxKey(String organizationId) =>
      'jobs.outbox.$organizationId';

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
  }) async {
    final create = JobCreatePrintJobCreate(
      id: newIdempotencyKey(),
      type: 'print',
      printerId: printerId,
      executionMode: ExecutionMode.local,
      title: title,
      documentId: null,
      connectionId: connectionId,
      pageCount: pageCount,
      submittedAt: _now().toUtc(),
      settings: choices.toApi(),
    );
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
      return Job.fromApi(recorded);
    } on ApiUnreachable {
      return entry.asJob();
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
    outbox.removeWhere((entry) => entry.registered && entry.events.isEmpty);
    await _write(organizationId, outbox);
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
    return Job.fromApi(
      await apiCall(
        () => _client.api.jobs.cancelJob(orgId: organizationId, jobId: jobId),
      ),
    );
  }

  /// Records a new job with the settings of one that failed or was
  /// cancelled. Running it is the caller's part.
  Future<Job> retry({
    required String organizationId,
    required String jobId,
  }) async {
    return Job.fromApi(
      await apiCall(
        () => _client.api.jobs.retryJob(
          orgId: organizationId,
          jobId: jobId,
          idempotencyKey: newIdempotencyKey(),
        ),
      ),
    );
  }

  /// Forgets what is waiting. Call when the user signs out.
  Future<void> clear(Iterable<String> organizationIds) async {
    for (final id in organizationIds) {
      await _store.delete(_outboxKey(id));
    }
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
