import 'package:api_client/api_client.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/account/account.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;

  setUp(() async {
    backend = TestBackend();
    await backend.signedInBefore();
    // The phone registers itself as the app opens.
    await backend.auth.registerDevice();
  });
  tearDown(() => backend.close());

  DevicesCubit build() => DevicesCubit(authRepository: backend.auth);

  TypeMatcher<DevicesState> ready() => isA<DevicesState>().having(
    (s) => s.status,
    'status',
    DevicesStatus.ready,
  );

  test('starts out loading', () {
    final cubit = build();
    addTearDown(cubit.close);

    expect(cubit.state, const DevicesState());
    expect(cubit.state.status, DevicesStatus.loading);
  });

  blocTest<DevicesCubit, DevicesState>(
    'lists the sessions and the phones, this one first',
    setUp: () {
      // The backend lists them in no particular order.
      backend
        ..sessionList = backend.sessionList.reversed.toList()
        ..deviceList = backend.deviceList.reversed.toList();
    },
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => [
      const DevicesState(),
      ready()
          .having((s) => s.sessions.map((x) => x.isCurrent), 'sessions', [
            true,
            false,
          ])
          .having((s) => s.devices.map((x) => x.isThisDevice), 'devices', [
            true,
            false,
          ])
          .having(
            (s) => s.deviceOf(s.sessions.first)?.label,
            'this session is on',
            'iPhone 15 Pro',
          )
          .having((s) => s.deviceOf(s.sessions.last), 'the other', isNull),
    ],
  );

  blocTest<DevicesCubit, DevicesState>(
    'says why the list could not be read',
    setUp: () => backend.offline = true,
    build: build,
    act: (cubit) => cubit.load(),
    skip: 1,
    expect: () => [
      isA<DevicesState>()
          .having((s) => s.status, 'status', DevicesStatus.failed)
          .having((s) => s.error, 'error', isA<ApiUnreachable>()),
    ],
  );

  blocTest<DevicesCubit, DevicesState>(
    'signs another device out',
    build: build,
    act: (cubit) async {
      await cubit.load();
      await cubit.signOut(cubit.state.sessions.last);
    },
    skip: 2,
    expect: () => [
      ready().having((s) => s.busyId, 'busy', 'session-2'),
      ready()
          .having((s) => s.sessions.map((x) => x.id), 'sessions', ['session-1'])
          .having((s) => s.busyId, 'busy', isNull),
    ],
    verify: (_) => expect(backend.sessionList, hasLength(1)),
  );

  blocTest<DevicesCubit, DevicesState>(
    'forgets a phone',
    build: build,
    act: (cubit) async {
      await cubit.load();
      await cubit.forget(cubit.state.devices.last);
    },
    skip: 3,
    expect: () => [
      ready().having((s) => s.devices.map((x) => x.id), 'devices', [
        'device-1',
      ]),
    ],
    verify: (_) => expect(backend.deviceList, hasLength(1)),
  );

  blocTest<DevicesCubit, DevicesState>(
    'keeps the list and says why when a change is refused',
    build: build,
    act: (cubit) async {
      await cubit.load();
      backend.offline = true;
      await cubit.signOut(cubit.state.sessions.last);
    },
    skip: 3,
    expect: () => [
      ready()
          .having((s) => s.sessions, 'sessions', hasLength(2))
          .having((s) => s.error, 'error', isA<ApiUnreachable>()),
    ],
  );

  test('makes one change at a time', () async {
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.load();

    final first = cubit.signOut(cubit.state.sessions.last);
    await cubit.forget(cubit.state.devices.last);
    await first;

    expect(backend.sessionList, hasLength(1));
    expect(backend.deviceList, hasLength(2));
  });
}
