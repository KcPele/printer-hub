import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/printers/printers.dart';
import 'package:printers_repository/printers_repository.dart';

import '../../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';

void main() {
  late TestBackend backend;
  late PrintersCubit printers;

  setUp(() async {
    backend = TestBackend()..printerList = [printerBody()];
    printers = PrintersCubit(
      printersRepository: backend.printers,
      organizationId: _org,
      organizationChanges: const Stream.empty(),
    );
    await printers.load();
  });
  tearDown(() async {
    await printers.close();
    await backend.close();
  });

  ConnectionsCubit build() => ConnectionsCubit(
    printersRepository: backend.printers,
    printersCubit: printers,
    organizationId: _org,
    printerId: 'printer-1',
  );

  List<String> types(ConnectionsState state) => [
    for (final connection in state.connections) connection.type.json!,
  ];

  TypeMatcher<ConnectionsState> ready() => isA<ConnectionsState>().having(
    (s) => s.status,
    'status',
    ConnectionsStatus.ready,
  );

  test('starts out loading', () {
    final cubit = build();
    addTearDown(cubit.close);

    expect(cubit.state, const ConnectionsState());
    expect(cubit.state.busy, isFalse);
  });

  blocTest<ConnectionsCubit, ConnectionsState>(
    'lists the connections, the one tried first at the top',
    build: build,
    act: (cubit) => cubit.load(),
    skip: 1,
    expect: () => [
      ready().having(types, 'types', ['ipp', 'escl']),
    ],
  );

  blocTest<ConnectionsCubit, ConnectionsState>(
    'says why the connections could not be read',
    setUp: () => backend.offline = true,
    build: build,
    act: (cubit) => cubit.load(),
    skip: 1,
    expect: () => [
      isA<ConnectionsState>()
          .having((s) => s.status, 'status', ConnectionsStatus.failed)
          .having((s) => s.error, 'error', isA<ApiUnreachable>()),
    ],
  );

  blocTest<ConnectionsCubit, ConnectionsState>(
    'makes a connection the one tried first, everywhere',
    build: build,
    act: (cubit) async {
      await cubit.load();
      await cubit.preferFirst(cubit.state.connections.last);
    },
    skip: 2,
    expect: () => [
      ready().having((s) => s.busy, 'busy', isTrue),
      ready()
          .having(types, 'types', ['escl', 'ipp'])
          .having((s) => s.busy, 'busy', isFalse),
    ],
    verify: (_) => expect(
      printers.state.printers.single.connections.first.type,
      ConnectionType.escl,
    ),
  );

  blocTest<ConnectionsCubit, ConnectionsState>(
    'removes a connection',
    build: build,
    act: (cubit) async {
      await cubit.load();
      await cubit.remove(cubit.state.connections.last);
    },
    skip: 3,
    expect: () => [
      ready().having(types, 'types', ['ipp']),
    ],
    verify: (_) =>
        expect(printers.state.printers.single.connections, hasLength(1)),
  );

  blocTest<ConnectionsCubit, ConnectionsState>(
    'adds the ways in found at another address',
    setUp: () => backend.plugInPrinter(),
    build: build,
    act: (cubit) async {
      await cubit.load();
      await cubit.addAddress('192.168.1.77');
    },
    skip: 3,
    expect: () => [
      ready()
          .having(types, 'types', ['ipp', 'escl', 'ipp', 'escl'])
          .having((s) => s.notice, 'notice', ConnectionsNotice.added)
          .having(
            (s) => s.connections.last.configuration.host,
            'host',
            '192.168.1.77',
          ),
    ],
  );

  blocTest<ConnectionsCubit, ConnectionsState>(
    'says when an address brings nothing new',
    setUp: () => backend.plugInPrinter(),
    build: build,
    act: (cubit) async {
      await cubit.load();
      await cubit.addAddress('192.168.1.40');
    },
    skip: 3,
    expect: () => [
      ready()
          .having(types, 'types', ['ipp', 'escl'])
          .having((s) => s.notice, 'notice', ConnectionsNotice.nothingNew),
    ],
  );

  blocTest<ConnectionsCubit, ConnectionsState>(
    'says when nothing answers at the address, and keeps the list',
    build: build,
    act: (cubit) async {
      await cubit.load();
      await cubit.addAddress('10.9.9.9');
    },
    skip: 3,
    expect: () => [
      ready()
          .having(types, 'types', ['ipp', 'escl'])
          .having(
            (s) => s.probeFailure,
            'probeFailure',
            ProbeFailureKind.unreachable,
          ),
    ],
  );

  blocTest<ConnectionsCubit, ConnectionsState>(
    'replaces the password kept with a connection',
    build: build,
    act: (cubit) async {
      await cubit.load();
      await cubit.setPassword(
        cubit.state.connections.first,
        userName: 'ada',
        password: 'new',
      );
    },
    skip: 3,
    expect: () => [
      ready()
          .having((s) => s.connections.first.hasCredentials, 'kept', isTrue)
          .having((s) => s.notice, 'notice', ConnectionsNotice.passwordChanged),
    ],
    verify: (_) => expect(backend.printerPasswords['printer-1'], {
      'username': 'ada',
      'password': 'new',
    }),
  );

  blocTest<ConnectionsCubit, ConnectionsState>(
    'keeps the list and says why when a change is refused',
    build: build,
    act: (cubit) async {
      await cubit.load();
      backend.offline = true;
      await cubit.remove(cubit.state.connections.last);
    },
    skip: 3,
    expect: () => [
      ready()
          .having(types, 'types', ['ipp', 'escl'])
          .having((s) => s.error, 'error', isA<ApiUnreachable>()),
    ],
  );

  test(
    'makes one change at a time, and none before the list is read',
    () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.addAddress('192.168.1.77');
      expect(cubit.state, const ConnectionsState());

      await cubit.load();
      final first = cubit.remove(cubit.state.connections.last);
      await cubit.remove(cubit.state.connections.first);
      await first;

      expect(types(cubit.state), ['ipp']);
    },
  );
}
