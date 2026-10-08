import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/notifications/notifications.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;

  setUp(() async {
    backend = TestBackend()
      ..notificationList = [
        notificationBody(id: 'notification-3', title: 'Scan failed'),
        notificationBody(id: 'notification-2', title: 'Copy finished'),
        notificationBody(readAt: '2026-10-07T09:00:00Z'),
      ];
    await backend.signedInBefore();
  });
  tearDown(() => backend.close());

  NotificationsCubit build() =>
      NotificationsCubit(notificationsRepository: backend.notifications);

  Future<NotificationsCubit> loaded() async {
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.load();
    return cubit;
  }

  List<bool> read(NotificationsState state) => [
    for (final one in state.notifications) one.isRead,
  ];

  blocTest<NotificationsCubit, NotificationsState>(
    'lists what the account was told, newest first',
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => [
      const NotificationsState(),
      isA<NotificationsState>()
          .having((s) => s.status, 'status', NotificationsStatus.ready)
          .having(
            (s) => [for (final one in s.notifications) one.title],
            'titles',
            ['Scan failed', 'Copy finished', 'Print finished'],
          )
          .having((s) => s.hasUnread, 'unread', isTrue)
          .having((s) => s.next, 'next', isNull),
    ],
  );

  blocTest<NotificationsCubit, NotificationsState>(
    'says why the list cannot be read',
    setUp: () => backend.offline = true,
    build: build,
    act: (cubit) => cubit.load(),
    skip: 1,
    expect: () => [
      isA<NotificationsState>()
          .having((s) => s.status, 'status', NotificationsStatus.failed)
          .having((s) => s.error, 'error', isA<ApiUnreachable>()),
    ],
  );

  test('says nothing once the screen has gone', () async {
    final cubit = build();
    final loading = cubit.load();
    await cubit.close();
    await expectLater(loading, completes);

    backend.offline = true;
    final other = build();
    final failing = other.load();
    await other.close();
    await expectLater(failing, completes);
  });

  group('more', () {
    setUp(() => backend.notificationPageSize = 2);

    test('reads on, a page at a time', () async {
      final cubit = await loaded();
      expect(cubit.state.notifications, hasLength(2));

      final first = cubit.more();
      await cubit.more();
      await first;

      expect(cubit.state.notifications, hasLength(3));
      expect(cubit.state.next, isNull);
      expect(backend.sent('GET /notifications'), hasLength(2));

      await cubit.more();
      expect(backend.sent('GET /notifications'), hasLength(2));
    });

    test('keeps what it has when the next page cannot be read', () async {
      final cubit = await loaded();
      backend.offline = true;

      await cubit.more();

      expect(cubit.state.notifications, hasLength(2));
      expect(cubit.state.error, isA<ApiUnreachable>());
      expect(cubit.state.loadingMore, isFalse);
    });

    test('says nothing once the screen has gone', () async {
      final cubit = build();
      await cubit.load();
      final late = cubit.more();
      await cubit.close();
      await expectLater(late, completes);

      final other = build();
      await other.load();
      backend.offline = true;
      final failing = other.more();
      await other.close();
      await expectLater(failing, completes);
    });
  });

  group('read', () {
    test('marks one read, on the screen and with the API', () async {
      final cubit = await loaded();

      await cubit.read(cubit.state.notifications.first);

      expect(read(cubit.state), [true, false, true]);
      expect(backend.notificationList.first['read_at'], isNotNull);
    });

    test('shows it read though the API cannot be told', () async {
      final cubit = await loaded();
      backend.offline = true;

      await cubit.read(cubit.state.notifications.first);

      expect(read(cubit.state), [true, false, true]);
    });

    test('has nothing to do for one already read', () async {
      final cubit = await loaded();

      await cubit.read(cubit.state.notifications.last);

      expect(backend.sent('POST /notifications/notification-1/read'), isEmpty);
    });
  });

  group('readAll', () {
    test('marks everything read', () async {
      final cubit = await loaded();

      await cubit.readAll();

      expect(read(cubit.state), [true, true, true]);
      expect(cubit.state.hasUnread, isFalse);
      expect(
        backend.notificationList.every((one) => one['read_at'] != null),
        isTrue,
      );

      // There is nothing left to mark.
      await cubit.readAll();
      expect(backend.sent('POST /notifications/read-all'), hasLength(1));
    });

    test('puts them back as they were when the API cannot be told', () async {
      final cubit = await loaded();
      backend.offline = true;

      await cubit.readAll();

      expect(read(cubit.state), [false, false, true]);
      expect(cubit.state.error, isA<ApiUnreachable>());
    });

    test('says nothing once the screen has gone', () async {
      final cubit = build();
      await cubit.load();
      backend.offline = true;
      final failing = cubit.readAll();
      await cubit.close();
      await expectLater(failing, completes);
    });
  });
}
