import 'dart:convert';

import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:local_store/local_store.dart';

const _org = 'org-1';
const _jobs = '/api/v1/organizations/$_org/jobs';

void main() {
  late FakeApi api;
  late InMemorySecureStore store;
  late JobsRepository repository;
  var offline = false;

  Map<String, dynamic> bodyOf(RequestOptions request) {
    return jsonDecode(jsonEncode(request.data)) as Map<String, dynamic>;
  }

  List<dynamic> outbox() =>
      jsonDecode(store.values['jobs.outbox.$_org'] ?? '[]') as List<dynamic>;

  /// Answers like the backend: a created job echoes what was sent.
  Future<FakeResponse> backend(RequestOptions request) async {
    if (offline) throw const FormatException('offline');
    final path = request.path.replaceFirst(_jobs, '');
    if (request.method == 'POST' && path.isEmpty) {
      final sent = bodyOf(request);
      return FakeResponse(
        201,
        jobBody(
          id: sent['id'] as String,
          title: sent['title'] as String?,
          copies: (sent['settings'] as Map)['copies'] as int,
        ),
      );
    }
    if (path == '/batch') {
      return FakeResponse(200, {
        'results': [
          for (final item in bodyOf(request)['items'] as List<dynamic>)
            {
              'idempotency_key': (item as Map)['idempotency_key'],
              'outcome': 'created',
              'job': jobBody(id: (item['job'] as Map)['id'] as String),
              'error': null,
            },
        ],
      });
    }
    if (path.endsWith('/events') && request.method == 'GET') {
      return const FakeResponse(200, [
        {
          'id': 'event-1',
          'status': 'printing',
          'connection_id': null,
          'connection_type': 'ipp',
          'error_code': null,
          'error_message': null,
          'reported_by_user_id': null,
          'detail': <String, Object?>{},
          'occurred_at': '2026-10-07T10:00:30Z',
          'created_at': '2026-10-07T10:00:30Z',
        },
      ]);
    }
    if (request.method == 'GET' && path.isEmpty) {
      return FakeResponse(200, {
        'items': [jobBody(), jobBody(id: 'job-2', type: 'scan', title: null)],
        'next_cursor': 'next-page',
      });
    }
    return FakeResponse(
      200,
      jobBody(
        status: path.endsWith('/cancel')
            ? 'cancelled'
            : path.endsWith('/retry')
            ? 'queued'
            : 'printing',
      ),
    );
  }

  setUp(() {
    offline = false;
    api = FakeApi(backend);
    store = InMemorySecureStore();
    final client = PrinterHubClient(
      baseUrl: Uri.parse('https://api.example.com'),
      tokenStore: InMemoryTokenStore(),
      httpClientAdapter: api,
    );
    addTearDown(client.close);
    repository = JobsRepository(
      client: client,
      store: store,
      now: () => DateTime.utc(2026, 10, 8, 9, 30),
    );
  });

  Future<Job> start({String title = 'Report.pdf'}) {
    return repository.startPrint(
      organizationId: _org,
      printerId: 'printer-1',
      title: title,
      choices: const PrintChoices(copies: 2, sides: 'two_sided_long_edge'),
      pageCount: 3,
      connectionId: 'connection-ipp-1',
    );
  }

  group('startPrint', () {
    test(
      'records the job with the backend, under its own id and key',
      () async {
        final job = await start();

        final request = api.requests.single;
        final sent = bodyOf(request);
        expect(request.path, _jobs);
        expect(request.headers['Idempotency-Key'], hasLength(36));
        expect(sent['id'], job.id);
        expect(sent['id'], isNot(request.headers['Idempotency-Key']));
        // It begins with the time, so the history lists it in its place.
        expect(job.id, startsWith('01a11ad9-21c0-7'));
        expect(sent['type'], 'print');
        expect(sent['printer_id'], 'printer-1');
        expect(sent['execution_mode'], 'local');
        expect(sent['title'], 'Report.pdf');
        expect(sent['page_count'], 3);
        expect(sent['connection_id'], 'connection-ipp-1');
        expect(sent['submitted_at'], '2026-10-08T09:30:00.000Z');
        expect(sent['settings'], containsPair('copies', 2));
        expect(sent['settings'], containsPair('duplex', 'two_sided_long_edge'));

        expect(job.status, 'queued');
        expect(job.kind, 'print');
        expect(job.print!.copies, 2);
        expect(job.waitingToSync, isFalse);
        // Nothing is left to send.
        expect(outbox(), isEmpty);
      },
    );

    test('starts offline too, and keeps the job to send later', () async {
      offline = true;

      final job = await start();

      expect(job.waitingToSync, isTrue);
      expect(job.status, 'queued');
      expect(job.title, 'Report.pdf');
      expect(job.print!.twoSided, isTrue);
      expect(job.submittedAt, DateTime.utc(2026, 10, 8, 9, 30));
      expect((await repository.waiting(_org)).single, job);
    });

    test('says why the backend will not have the job, and drops it', () async {
      api.handler = (_) async => FakeResponse.problem(403, 'permission.denied');

      await expectLater(start(), throwsA(isA<ApiProblem>()));

      expect(await repository.waiting(_org), isEmpty);
    });
  });

  group('report', () {
    test('tells the backend how a job is going', () async {
      final job = await start();

      await repository.report(
        _org,
        job.id,
        JobUpdate(
          status: 'failed',
          connectionId: 'connection-ipp-1',
          errorCode: 'ipp.client-error-not-possible',
          errorMessage: 'x' * 600,
          printerJobRef: '42',
          pageCount: 3,
        ),
      );

      final request = api.requests.last;
      final sent = bodyOf(request);
      expect(request.path, '$_jobs/${job.id}/events');
      expect(sent['status'], 'failed');
      expect(sent['connection_id'], 'connection-ipp-1');
      expect(sent['error_code'], 'ipp.client-error-not-possible');
      expect((sent['error_message'] as String).length, 500);
      expect(sent['printer_job_ref'], '42');
      expect(sent['occurred_at'], '2026-10-08T09:30:00.000Z');
    });

    test('keeps a change it cannot send, for a job the backend has', () async {
      final job = await start();
      offline = true;

      await repository.report(
        _org,
        job.id,
        const JobUpdate(status: 'printing'),
      );
      await repository.report(
        _org,
        job.id,
        const JobUpdate(status: 'completed'),
      );

      expect((outbox().single as Map)['events'], hasLength(2));
      // The backend knows the job, so it is not among those waiting.
      expect(await repository.waiting(_org), isEmpty);
    });

    test('holds changes back behind the ones still waiting', () async {
      final job = await start();
      offline = true;
      await repository.report(
        _org,
        job.id,
        const JobUpdate(status: 'printing'),
      );
      offline = false;
      final sentBefore = api.requests.length;

      await repository.report(
        _org,
        job.id,
        const JobUpdate(status: 'completed'),
      );

      // Sent out of order, the backend would refuse the earlier one.
      expect(api.requests, hasLength(sentBefore));
      expect((outbox().single as Map)['events'], hasLength(2));
    });

    test('follows a job started offline by what happened to it', () async {
      offline = true;
      final job = await start();

      await repository.report(
        _org,
        job.id,
        const JobUpdate(status: 'printing'),
      );

      expect((await repository.waiting(_org)).single.status, 'printing');
    });

    test('does not let a refused change stop anything', () async {
      final job = await start();
      api.handler = (_) async =>
          FakeResponse.problem(409, 'job.invalid_transition');

      await repository.report(_org, job.id, const JobUpdate(status: 'queued'));

      expect(outbox(), isEmpty);
    });
  });

  group('sync', () {
    test('has nothing to do when nothing is waiting', () async {
      expect(await repository.sync(_org), 0);
      expect(api.requests, isEmpty);
    });

    test(
      'sends the jobs started offline, with what happened to them',
      () async {
        offline = true;
        final first = await start();
        final second = await start(title: 'Photo.jpg');
        await repository.report(
          _org,
          first.id,
          const JobUpdate(status: 'printing'),
        );
        await repository.report(
          _org,
          first.id,
          const JobUpdate(status: 'completed'),
        );
        offline = false;
        api.requests.clear();

        expect(await repository.sync(_org), 0);

        final request = api.requests.single;
        expect(request.path, '$_jobs/batch');
        final items = bodyOf(request)['items'] as List<dynamic>;
        expect(items.map((item) => ((item as Map)['job'] as Map)['id']), [
          first.id,
          second.id,
        ]);
        expect(
          ((items.first as Map)['events'] as List).map(
            (e) => (e as Map)['status'],
          ),
          ['printing', 'completed'],
        );
        expect(await repository.waiting(_org), isEmpty);
        expect(outbox(), isEmpty);
      },
    );

    test('sends the same job with the same key every time', () async {
      offline = true;
      await start();
      await repository.sync(_org);
      offline = false;

      await repository.sync(_org);

      final keys = [
        for (final request in api.requests)
          if (request.path.endsWith('/batch'))
            ((bodyOf(request)['items'] as List).single
                as Map)['idempotency_key'],
      ];
      expect(keys, hasLength(2));
      expect(keys.toSet(), hasLength(1));
    });

    test('sends waiting changes for a job the backend has, in order', () async {
      final job = await start();
      offline = true;
      await repository.report(
        _org,
        job.id,
        const JobUpdate(status: 'printing'),
      );
      await repository.report(
        _org,
        job.id,
        const JobUpdate(status: 'completed'),
      );
      offline = false;
      api.requests.clear();

      expect(await repository.sync(_org), 0);

      expect(api.requests.map((r) => bodyOf(r)['status']), [
        'printing',
        'completed',
      ]);
      expect(outbox(), isEmpty);
    });

    test(
      'gives up on a change the backend refuses, and sends the rest',
      () async {
        final job = await start();
        offline = true;
        await repository.report(
          _org,
          job.id,
          const JobUpdate(status: 'printing'),
        );
        await repository.report(
          _org,
          job.id,
          const JobUpdate(status: 'completed'),
        );
        offline = false;
        var asked = 0;
        api.handler = (_) async => ++asked == 1
            ? FakeResponse.problem(409, 'job.invalid_transition')
            : FakeResponse(200, jobBody(status: 'completed'));

        expect(await repository.sync(_org), 0);
        expect(asked, 2);
      },
    );

    test('keeps everything while the API stays out of reach', () async {
      offline = true;
      await start();
      await start();

      expect(await repository.sync(_org), 2);
      expect(await repository.waiting(_org), hasLength(2));
    });

    test('keeps a job the backend did not answer for', () async {
      offline = true;
      await start();
      offline = false;
      api.handler = (_) async =>
          const FakeResponse(200, {'results': <Object>[]});

      expect(await repository.sync(_org), 1);
    });
  });

  group('history', () {
    test('lists a page of jobs, of any kind', () async {
      final page = await repository.list(
        organizationId: _org,
        printerId: 'printer-1',
        kind: 'print',
        statuses: ['failed', 'cancelled'],
        cursor: 'from-here',
      );

      expect(page.jobs.map((job) => job.kind), ['print', 'scan']);
      expect(page.jobs.last.print, isNull);
      expect(page.jobs.last.title, isNull);
      expect(page.next, 'next-page');
      final query = api.requests.single.queryParameters;
      expect(query['printer_id'], 'printer-1');
      expect(query['type'], 'print');
      // Sent as their names: `status=failed&status=cancelled`.
      expect((query['status'] as List).map((status) => '$status'), [
        'failed',
        'cancelled',
      ]);
      expect(query['cursor'], 'from-here');
    });

    test('lists everything when not narrowed', () async {
      await repository.list(organizationId: _org);

      final query = api.requests.single.queryParameters;
      expect(query.containsKey('type'), isFalse);
      expect(query.containsKey('status'), isFalse);
    });

    test('reads one job and what happened to it', () async {
      final job = await repository.get(organizationId: _org, jobId: 'job-1');
      final events = await repository.events(
        organizationId: _org,
        jobId: 'job-1',
      );

      expect(job.status, 'printing');
      expect(job.isFinished, isFalse);
      expect(events.single.status, 'printing');
      expect(events.single.connectionType, 'ipp');
      expect(events.single.occurredAt, DateTime.utc(2026, 10, 7, 10, 0, 30));
      expect(
        events.single,
        isNot(JobEvent(status: 'x', occurredAt: DateTime(1))),
      );
    });

    test('cancels a job, and records a retry as a new one', () async {
      final cancelled = await repository.cancel(
        organizationId: _org,
        jobId: 'job-1',
      );
      final retried = await repository.retry(
        organizationId: _org,
        jobId: 'job-1',
      );

      expect(cancelled.status, 'cancelled');
      expect(cancelled.isFinished, isTrue);
      expect(cancelled.canRetry, isTrue);
      expect(cancelled.completedAt, isNotNull);
      expect(retried.canRetry, isFalse);
      expect(api.requests.first.path, '$_jobs/job-1/cancel');
      expect(api.requests.last.path, '$_jobs/job-1/retry');
      expect(api.requests.last.headers['Idempotency-Key'], hasLength(36));
    });
  });

  group('changes', () {
    late int changes;

    setUp(() {
      changes = 0;
      final watching = repository.changes.listen((_) => changes++);
      addTearDown(watching.cancel);
    });

    test('a job starting is one, online or off', () async {
      await start();
      await pumpEventQueue();
      expect(changes, 1);

      offline = true;
      await start();
      await pumpEventQueue();
      expect(changes, 2);
    });

    test('a job ending is one; a step on the way is not', () async {
      await repository.report(
        _org,
        'job-1',
        const JobUpdate(status: 'printing'),
      );
      await pumpEventQueue();
      expect(changes, 0);

      await repository.report(
        _org,
        'job-1',
        const JobUpdate(status: 'completed'),
      );
      await pumpEventQueue();
      expect(changes, 1);
    });

    test('what was waiting being sent is one', () async {
      offline = true;
      await start();
      await pumpEventQueue();
      changes = 0;

      await repository.sync(_org);
      await pumpEventQueue();
      expect(changes, 0);

      offline = false;
      await repository.sync(_org);
      await pumpEventQueue();
      expect(changes, 1);
    });

    test('cancelling and retrying are each one', () async {
      await repository.cancel(organizationId: _org, jobId: 'job-1');
      await repository.retry(organizationId: _org, jobId: 'job-1');
      await pumpEventQueue();
      expect(changes, 2);
    });
  });

  test('clear forgets what is waiting', () async {
    offline = true;
    await start();

    await repository.clear([_org]);

    expect(await repository.waiting(_org), isEmpty);
  });

  test('an outbox it cannot read is treated as empty', () async {
    store.values['jobs.outbox.$_org'] = 'not json';

    expect(await repository.waiting(_org), isEmpty);
  });

  group('models', () {
    test('choices change one at a time, and compare by value', () {
      const choices = PrintChoices(tray: 'tray-1', quality: 'draft');

      final changed = choices.copyWith(
        copies: 3,
        color: 'monochrome',
        sides: 'two_sided_short_edge',
        mediaSize: () => 'iso_a4_210x297mm',
        tray: () => null,
        pageRanges: () => '1-2',
        orientation: 'landscape',
        collate: false,
      );

      expect(changed.copies, 3);
      expect(changed.color, 'monochrome');
      expect(changed.twoSided, isTrue);
      expect(changed.mediaSize, 'iso_a4_210x297mm');
      expect(changed.tray, isNull);
      expect(changed.quality, 'draft');
      expect(changed.pageRanges, '1-2');
      expect(changed.orientation, 'landscape');
      expect(changed.collate, isFalse);
      expect(choices.copyWith(quality: () => 'high').quality, 'high');
      expect(choices.copyWith(), choices);
      expect(choices, isNot(changed));
    });

    test('choices are read with the defaults for what is missing', () {
      expect(PrintChoices.fromJson(const {}), const PrintChoices());
    });

    test('a job is read with the defaults for what is missing', () {
      final job = Job.fromJson(const {'id': 'j', 'printer_id': 'p'});

      expect(job.kind, 'print');
      expect(job.status, 'queued');
      expect(job.submittedAt.millisecondsSinceEpoch, 0);
      expect(job.print, isNull);
      expect(job.fallbackOccurred, isFalse);
    });

    test('an update compares by value', () {
      expect(
        const JobUpdate(status: 'printing'),
        const JobUpdate(status: 'printing'),
      );
      expect(
        JobUpdate(status: 'printing', pageCount: [1].length),
        isNot(const JobUpdate(status: 'printing')),
      );
    });
  });
}
