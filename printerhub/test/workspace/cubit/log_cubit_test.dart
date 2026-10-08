import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/workspace/workspace.dart';

import '../../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';

void main() {
  late TestBackend backend;

  setUp(() async {
    backend = TestBackend()
      ..auditList = [
        auditBody(id: 'audit-3', action: 'invitation.created'),
        auditBody(id: 'audit-2', action: 'printer.updated'),
        auditBody(),
      ];
    await backend.signedInBefore();
  });
  tearDown(() => backend.close());

  LogCubit build() => LogCubit(
    organizationsRepository: backend.organizations,
    organizationId: _org,
  );

  List<String> actions(LogState state) => [
    for (final logged in state.actions) logged.action,
  ];

  test('reads what was done, newest first', () async {
    final cubit = build();
    addTearDown(cubit.close);
    expect(cubit.state, const LogState());

    await cubit.load();

    expect(cubit.state.status, LogStatus.ready);
    expect(actions(cubit.state), [
      'invitation.created',
      'printer.updated',
      'printer.created',
    ]);
    expect(cubit.state.next, isNull);
  });

  test('says why the log cannot be read', () async {
    backend.fail(
      'GET /organizations/$_org/audit-logs',
      403,
      'permission.denied',
    );
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, LogStatus.failed);
    expect(cubit.state.error, isA<ApiProblem>());
  });

  group('more', () {
    setUp(() => backend.auditPageSize = 2);

    test('reads on, a page at a time', () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.load();
      expect(actions(cubit.state), hasLength(2));

      final first = cubit.more();
      expect(cubit.state.loadingMore, isTrue);
      await cubit.more();
      await first;

      expect(actions(cubit.state), hasLength(3));
      expect(cubit.state.next, isNull);
      expect(cubit.state.loadingMore, isFalse);

      await cubit.more();
      expect(backend.sent('GET /organizations/$_org/audit-logs'), hasLength(2));
    });

    test('keeps what it has when the next page cannot be read', () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.load();
      backend.offline = true;

      await cubit.more();

      expect(actions(cubit.state), hasLength(2));
      expect(cubit.state.error, isA<ApiUnreachable>());
      expect(cubit.state.next, '2');
    });
  });

  test('says nothing once the screen has gone', () async {
    backend.auditPageSize = 2;
    for (final offline in [false, true]) {
      backend.offline = offline;
      final cubit = build();
      final loading = cubit.load();
      await cubit.close();
      await expectLater(loading, completes);
    }
    for (final offline in [false, true]) {
      backend.offline = false;
      final cubit = build();
      await cubit.load();
      backend.offline = offline;
      final late = cubit.more();
      await cubit.close();
      await expectLater(late, completes);
    }
  });
}
