import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/library/cubit/sync_cubit.dart';

import '../../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';
const _documents = 'POST /organizations/$_org/documents';

void main() {
  late TestBackend backend;
  late StreamController<String?> workspaces;

  setUp(() async {
    backend = TestBackend();
    await backend.signedInBefore();
    workspaces = StreamController<String?>();
    addTearDown(workspaces.close);
  });
  tearDown(() => backend.close());

  SyncCubit build({String? organizationId = _org, Duration? every}) {
    final cubit = SyncCubit(
      library: backend.library,
      organizationId: organizationId,
      organizationChanges: workspaces.stream,
      every: every,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  Future<void> make(String name) {
    return backend.library.add(
      organizationId: _org,
      file: File('${backend.scans.path}/$name')..writeAsStringSync('%PDF'),
      mimeType: 'application/pdf',
    );
  }

  test('starts with nothing to say', () {
    expect(build().state, const SyncState());
  });

  test('counts what is waiting as it is made', () async {
    final cubit = build();

    await make('Note.pdf');
    await make('Other.pdf');
    await pumpEventQueue();

    expect(cubit.state.waiting, 2);
    expect(cubit.state.syncing, isFalse);
    expect(cubit.state.lastSynced, isNull);
  });

  test('sends what is waiting when asked, and says when it last '
      'did', () async {
    await make('Note.pdf');
    final cubit = build();

    final syncing = cubit.sync();
    await pumpEventQueue(times: 2);
    expect(cubit.state.syncing, isTrue);
    // One pass is asked for at a time.
    await cubit.sync();
    await syncing;

    expect(cubit.state.syncing, isFalse);
    expect(cubit.state.waiting, 0);
    expect(cubit.state.lastSynced, isNotNull);
    expect(backend.sent(_documents), hasLength(1));
  });

  test('says what is still waiting when the account cannot be '
      'reached', () async {
    await make('Note.pdf');
    backend.offline = true;
    final cubit = build();

    await cubit.sync();

    expect(cubit.state.waiting, 1);
    expect(cubit.state.syncing, isFalse);
    expect(cubit.state.lastSynced, isNull);
  });

  test('sends to a workspace as it is opened, and has nothing to send '
      'to without one', () async {
    await make('Note.pdf');
    final cubit = build(organizationId: null);
    await cubit.sync();
    expect(cubit.state, const SyncState());
    expect(backend.sent(_documents), isEmpty);

    workspaces.add(_org);
    await cubit.stream.firstWhere(
      (state) => !state.syncing && state.lastSynced != null,
    );
    expect(backend.sent(_documents), hasLength(1));

    // Signed out: nothing is counted.
    await make('Other.pdf');
    workspaces.add(null);
    await pumpEventQueue();
    expect(cubit.state, const SyncState());
  });

  test('sends from time to time while the app is open', () async {
    final cubit = build(every: const Duration(milliseconds: 20));
    var passes = 0;
    final watching = cubit.stream.listen((state) {
      if (state.syncing) passes++;
    });

    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(passes, greaterThanOrEqualTo(2));

    // And stops when the app goes.
    await watching.cancel();
    await cubit.close();
    final before = backend.library.lastSynced(_org);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(backend.library.lastSynced(_org), before);
  });

  test('says nothing once the app has gone', () async {
    await make('Note.pdf');
    final cubit = build();
    final syncing = cubit.sync();
    await cubit.close();
    await syncing;

    await make('Other.pdf');
    await pumpEventQueue();
  });
}
