import 'dart:async';

import 'package:api_client/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/notifications/notifications.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;
  late StreamController<bool> sessions;

  setUp(() async {
    backend = TestBackend()
      ..notificationList = [
        notificationBody(),
        notificationBody(id: 'notification-2'),
        notificationBody(id: 'notification-3', readAt: '2026-10-07T09:00:00Z'),
      ];
    sessions = StreamController<bool>.broadcast();
    await backend.signedInBefore();
  });
  tearDown(() async {
    await sessions.close();
    await backend.close();
  });

  UnreadCubit build({bool signedIn = true}) {
    final cubit = UnreadCubit(
      notificationsRepository: backend.notifications,
      signedIn: signedIn,
      signedInChanges: sessions.stream,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('starts at nothing, and counts when asked', () async {
    final cubit = build();
    expect(cubit.state, 0);

    await cubit.refresh();

    expect(cubit.state, 2);
  });

  test('does not count for nobody', () async {
    final cubit = build(signedIn: false);

    await cubit.refresh();

    expect(cubit.state, 0);
    expect(backend.sent('GET /notifications/unread-count'), isEmpty);
  });

  test(
    'counts when someone signs in, and forgets when they sign out',
    () async {
      final cubit = build(signedIn: false);

      sessions.add(true);
      await pumpEventQueue();
      expect(cubit.state, 2);

      sessions.add(false);
      await pumpEventQueue();
      expect(cubit.state, 0);
    },
  );

  test('counts again when something is read', () async {
    final cubit = build();
    await cubit.refresh();

    await backend.notifications.markRead('notification-1');
    await pumpEventQueue();

    expect(cubit.state, 1);
  });

  test('keeps the count it has when it cannot count', () async {
    final cubit = build();
    await cubit.refresh();
    backend.offline = true;

    await cubit.refresh();

    expect(cubit.state, 2);
  });

  test('drops a count that arrives after signing out, or after it has '
      'gone', () async {
    final cubit = build();
    final counting = cubit.refresh();
    sessions.add(false);
    await counting;
    await pumpEventQueue();
    expect(cubit.state, 0);

    final other = build();
    final late = other.refresh();
    await other.close();
    await expectLater(late, completes);
  });
}
