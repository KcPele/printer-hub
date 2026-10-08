import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/workspace/workspace.dart';

import '../../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';

void main() {
  late TestBackend backend;
  late StreamController<String?> workspaces;

  setUp(() async {
    backend = TestBackend()..features = {'local_ocr': true, 'print.pin': false};
    workspaces = StreamController<String?>.broadcast();
    await backend.signedInBefore();
  });
  tearDown(() async {
    await workspaces.close();
    await backend.close();
  });

  FeaturesCubit build({String? organizationId = _org}) {
    final cubit = FeaturesCubit(
      organizationsRepository: backend.organizations,
      organizationId: organizationId,
      organizationChanges: workspaces.stream,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('everything is off until it is known', () {
    final cubit = build();

    expect(cubit.state, isEmpty);
    expect(cubit.enabled('local_ocr'), isFalse);
  });

  test('reads what is switched on for the workspace', () async {
    final cubit = build();

    await cubit.load();

    expect(cubit.enabled('local_ocr'), isTrue);
    expect(cubit.enabled('print.pin'), isFalse);
    expect(cubit.enabled('never.heard.of'), isFalse);
  });

  test('has nothing to read without a workspace', () async {
    final cubit = build(organizationId: null);

    await cubit.load();

    expect(cubit.state, isEmpty);
    expect(backend.network.requests, isEmpty);
  });

  test('follows the workspace', () async {
    final cubit = build(organizationId: null);

    workspaces.add(_org);
    await pumpEventQueue();
    expect(cubit.enabled('local_ocr'), isTrue);

    workspaces.add(null);
    await pumpEventQueue();
    expect(cubit.state, isEmpty);
  });

  test('leaves everything off when it cannot be read', () async {
    backend.offline = true;
    final cubit = build();

    await cubit.load();

    expect(cubit.state, isEmpty);
  });

  test('drops an answer for a workspace no longer in use, or a screen '
      'that has gone', () async {
    final cubit = build();
    final loading = cubit.load();
    workspaces.add(null);
    await loading;
    await pumpEventQueue();
    expect(cubit.state, isEmpty);

    final other = build();
    final late = other.load();
    await other.close();
    await expectLater(late, completes);
  });
}
