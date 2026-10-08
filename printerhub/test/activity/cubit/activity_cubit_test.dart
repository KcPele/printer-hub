import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:printerhub/activity/activity.dart';

import '../../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';

void main() {
  late TestBackend backend;

  setUp(() async {
    backend = TestBackend()
      ..jobList = [
        jobBody(id: 'job-3', status: 'printing', title: 'Now.pdf'),
        jobBody(id: 'job-2', status: 'failed', title: 'Broken.pdf'),
        jobBody(status: 'completed'),
      ];
    await backend.signedInBefore();
  });
  tearDown(() => backend.close());

  ActivityCubit build() =>
      ActivityCubit(jobsRepository: backend.jobs, organizationId: _org);

  List<String> titles(ActivityState state) => [
    for (final job in state.visible) job.title!,
  ];

  Future<Job> startOffline({String title = 'Offline.pdf'}) async {
    backend.offline = true;
    final job = await backend.jobs.startPrint(
      organizationId: _org,
      printerId: 'printer-1',
      title: title,
      choices: const PrintChoices(),
    );
    return job;
  }

  test('starts by reading', () {
    final cubit = build();
    addTearDown(cubit.close);

    expect(cubit.state, const ActivityState());
    expect(cubit.state.visible, isEmpty);
  });

  blocTest<ActivityCubit, ActivityState>(
    'lists the jobs, newest first',
    build: build,
    act: (cubit) => cubit.load(),
    skip: 1,
    expect: () => [
      isA<ActivityState>()
          .having((s) => s.status, 'status', ActivityStatus.ready)
          .having(titles, 'titles', ['Now.pdf', 'Broken.pdf', 'Report.pdf'])
          .having((s) => s.next, 'next', isNull),
    ],
  );

  blocTest<ActivityCubit, ActivityState>(
    'narrows to the jobs that went wrong, and back',
    build: build,
    act: (cubit) async {
      await cubit.show(ActivityFilter.problems);
      await cubit.show(ActivityFilter.active);
      await cubit.show(ActivityFilter.done);
    },
    expect: () => [
      const ActivityState(filter: ActivityFilter.problems),
      isA<ActivityState>().having(titles, 'titles', ['Broken.pdf']),
      const ActivityState(filter: ActivityFilter.active),
      isA<ActivityState>().having(titles, 'titles', ['Now.pdf']),
      const ActivityState(filter: ActivityFilter.done),
      isA<ActivityState>().having(titles, 'titles', ['Report.pdf']),
    ],
  );

  blocTest<ActivityCubit, ActivityState>(
    'reads on, a page at a time',
    setUp: () => backend.jobPageSize = 2,
    build: build,
    act: (cubit) async {
      await cubit.load();
      await cubit.more();
      // There is no more after that.
      await cubit.more();
    },
    skip: 1,
    expect: () => [
      isA<ActivityState>()
          .having(titles, 'titles', ['Now.pdf', 'Broken.pdf'])
          .having((s) => s.next, 'next', '2'),
      isA<ActivityState>().having((s) => s.loadingMore, 'more', isTrue),
      isA<ActivityState>()
          .having(titles, 'titles', ['Now.pdf', 'Broken.pdf', 'Report.pdf'])
          .having((s) => s.loadingMore, 'more', isFalse)
          .having((s) => s.next, 'next', isNull),
    ],
  );

  blocTest<ActivityCubit, ActivityState>(
    'keeps what it has when the next page cannot be read',
    setUp: () => backend.jobPageSize = 2,
    build: build,
    act: (cubit) async {
      await cubit.load();
      backend.offline = true;
      await cubit.more();
    },
    skip: 3,
    expect: () => [
      isA<ActivityState>()
          .having(titles, 'titles', ['Now.pdf', 'Broken.pdf'])
          .having((s) => s.error, 'error', isA<ApiUnreachable>())
          .having((s) => s.next, 'next', '2'),
    ],
  );

  test('asks for one more page at a time', () async {
    backend.jobPageSize = 1;
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.load();
    backend.network.requests.clear();

    final first = cubit.more();
    await cubit.more();
    await first;

    expect(backend.network.requests, hasLength(1));
    expect(cubit.state.visible, hasLength(2));
  });

  blocTest<ActivityCubit, ActivityState>(
    'says why the history cannot be read',
    setUp: () => backend.offline = true,
    build: build,
    act: (cubit) => cubit.load(),
    skip: 1,
    expect: () => [
      isA<ActivityState>()
          .having((s) => s.status, 'status', ActivityStatus.failed)
          .having((s) => s.error, 'error', isA<ApiUnreachable>()),
    ],
  );

  blocTest<ActivityCubit, ActivityState>(
    'says what is wrong when the phone may not send what it kept',
    setUp: () async {
      await startOffline();
      backend
        ..offline = false
        ..fail('POST /organizations/$_org/jobs/batch', 403, 'permission.denied')
        ..fail('GET /organizations/$_org/jobs', 403, 'permission.denied');
    },
    build: build,
    act: (cubit) => cubit.load(),
    skip: 1,
    expect: () => [
      isA<ActivityState>()
          .having((s) => s.status, 'status', ActivityStatus.ready)
          .having(titles, 'titles', ['Offline.pdf'])
          .having((s) => s.error, 'error', isA<ApiProblem>()),
    ],
  );

  group('with a job started while offline', () {
    blocTest<ActivityCubit, ActivityState>(
      'shows it, though the history cannot be read',
      setUp: startOffline,
      build: build,
      act: (cubit) => cubit.load(),
      skip: 1,
      expect: () => [
        isA<ActivityState>()
            .having((s) => s.status, 'status', ActivityStatus.ready)
            .having(titles, 'titles', ['Offline.pdf'])
            .having((s) => s.visible.single.waitingToSync, 'waiting', isTrue)
            .having((s) => s.error, 'error', isA<ApiUnreachable>()),
      ],
    );

    blocTest<ActivityCubit, ActivityState>(
      'leaves it out when the filter does not let it through',
      setUp: startOffline,
      build: build,
      act: (cubit) => cubit.show(ActivityFilter.done),
      skip: 1,
      expect: () => [
        isA<ActivityState>()
            .having((s) => s.waiting, 'waiting', hasLength(1))
            .having((s) => s.visible, 'visible', isEmpty),
      ],
    );

    test('sends it once the API can be reached, and lists it', () async {
      await startOffline();
      backend.offline = false;
      final cubit = build();
      addTearDown(cubit.close);

      await cubit.load();
      await pumpEventQueue();

      expect(cubit.state.waiting, isEmpty);
      expect(titles(cubit.state), [
        'Offline.pdf',
        'Now.pdf',
        'Broken.pdf',
        'Report.pdf',
      ]);
      expect(cubit.state.visible.first.waitingToSync, isFalse);
    });
  });

  test('reads again by itself when a job begins', () async {
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.load();

    await backend.jobs.startPrint(
      organizationId: _org,
      printerId: 'printer-1',
      title: 'New.pdf',
      choices: const PrintChoices(),
    );
    await pumpEventQueue();

    expect(titles(cubit.state).first, 'New.pdf');
  });

  test('drops an answer that a newer read has overtaken', () async {
    final cubit = build();
    addTearDown(cubit.close);

    final slow = cubit.load();
    await cubit.show(ActivityFilter.problems);
    await slow;

    expect(cubit.state.filter, ActivityFilter.problems);
    expect(titles(cubit.state), ['Broken.pdf']);
  });

  test('says nothing once the screen has gone', () async {
    final cubit = build();
    final loading = cubit.load();
    await cubit.close();

    await expectLater(loading, completes);
  });
}
