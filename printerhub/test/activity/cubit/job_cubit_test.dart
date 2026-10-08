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
      ..jobList = [jobBody(status: 'printing')]
      ..jobEvents['job-1'] = [
        {'status': 'processing', 'connection_id': 'connection-ipp-1'},
        {'status': 'printing', 'connection_id': 'connection-ipp-1'},
      ];
    await backend.signedInBefore();
  });
  tearDown(() => backend.close());

  JobCubit build({Job? known, String jobId = 'job-1'}) => JobCubit(
    jobsRepository: backend.jobs,
    organizationId: _org,
    jobId: jobId,
    known: known,
  );

  test('starts with what the list knew of the job', () {
    final known = Job.fromJson(jobBody().cast());
    final cubit = build(known: known);
    addTearDown(cubit.close);

    expect(cubit.state, JobState(job: known));
    expect(cubit.state.status, JobLoadStatus.loading);
  });

  blocTest<JobCubit, JobState>(
    'reads the job and what happened to it',
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => [
      const JobState(),
      isA<JobState>()
          .having((s) => s.status, 'status', JobLoadStatus.ready)
          .having((s) => s.job!.status, 'job', 'printing')
          .having(
            (s) => [for (final event in s.events) event.status],
            'events',
            ['processing', 'printing'],
          ),
    ],
  );

  blocTest<JobCubit, JobState>(
    'says why the job cannot be read',
    build: () => build(jobId: 'missing'),
    act: (cubit) => cubit.load(),
    skip: 1,
    expect: () => [
      isA<JobState>()
          .having((s) => s.status, 'status', JobLoadStatus.failed)
          .having((s) => s.error, 'error', isA<ApiProblem>()),
    ],
  );

  test('a job that is only on the phone is shown as it is', () async {
    final known = Job.fromJson(jobBody().cast(), waitingToSync: true);
    final cubit = build(known: known);
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.cancel();

    expect(cubit.state, JobState(status: JobLoadStatus.ready, job: known));
    expect(backend.network.requests, isEmpty);
  });

  group('cancel', () {
    blocTest<JobCubit, JobState>(
      'marks the job cancelled, and reads what happened again',
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.cancel();
        // Nothing is left to cancel.
        await cubit.cancel();
      },
      skip: 2,
      expect: () => [
        isA<JobState>().having((s) => s.cancelling, 'cancelling', isTrue),
        isA<JobState>()
            .having((s) => s.job!.status, 'job', 'cancelled')
            .having((s) => s.cancelled, 'cancelled', isTrue)
            .having((s) => s.cancelling, 'cancelling', isFalse)
            .having((s) => s.events.last.status, 'last event', 'cancelled'),
      ],
    );

    blocTest<JobCubit, JobState>(
      'says why the job could not be marked',
      build: build,
      act: (cubit) async {
        await cubit.load();
        backend.fail(
          'POST /organizations/$_org/jobs/job-1/cancel',
          409,
          'job.invalid_transition',
        );
        await cubit.cancel();
      },
      skip: 3,
      expect: () => [
        isA<JobState>()
            .having((s) => s.job!.status, 'job', 'printing')
            .having((s) => s.cancelling, 'cancelling', isFalse)
            .having((s) => s.events, 'events', hasLength(2))
            .having((s) => s.error, 'error', isA<ApiProblem>()),
      ],
    );

    test('does nothing before there is a job', () async {
      final cubit = build();
      addTearDown(cubit.close);

      await cubit.cancel();

      expect(cubit.state, const JobState());
    });

    test('is asked for once at a time', () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.load();
      backend.network.requests.clear();

      final first = cubit.cancel();
      await cubit.cancel();
      await first;

      expect(
        backend.network.requests.where((r) => r.path.endsWith('/cancel')),
        hasLength(1),
      );
    });
  });
}
