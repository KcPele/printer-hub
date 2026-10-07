import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printer_protocols/printer_protocols.dart';
import 'package:printer_protocols/testing.dart';
import 'package:printerhub/printers/printers.dart';
import 'package:printers_repository/printers_repository.dart';

import '../../helpers/helpers.dart';

const _org = 'org-1';

void main() {
  late TestBackend backend;

  setUp(() => backend = TestBackend());
  tearDown(() => backend.close());

  AddPrinterCubit build() {
    return AddPrinterCubit(
      printersRepository: backend.printers,
      organizationId: _org,
    );
  }

  test('starts by waiting for an address', () {
    final cubit = build();
    addTearDown(cubit.close);

    expect(cubit.state, const AddPrinterState());
    expect(cubit.state.step, AddPrinterStep.address);
  });

  group('find', () {
    blocTest<AddPrinterCubit, AddPrinterState>(
      'describes the device at the address',
      setUp: () => backend.plugInPrinter(),
      build: build,
      act: (cubit) => cubit.find('192.168.1.40'),
      expect: () => [
        const AddPrinterState(
          step: AddPrinterStep.searching,
          address: '192.168.1.40',
        ),
        isA<AddPrinterState>()
            .having((s) => s.step, 'step', AddPrinterStep.found)
            .having((s) => s.address, 'address', '192.168.1.40')
            .having((s) => s.device!.model, 'model', 'VersaLink C7130')
            .having((s) => s.device!.scan!.hasFeeder, 'feeder', isTrue),
      ],
    );

    for (final (address, kind) in [
      ('192.168.1.99', ProbeFailureKind.unreachable),
      ('not an address', ProbeFailureKind.invalidAddress),
    ]) {
      blocTest<AddPrinterCubit, AddPrinterState>(
        'returns to the address with why "$address" found nothing',
        build: build,
        act: (cubit) => cubit.find(address),
        expect: () => [
          AddPrinterState(step: AddPrinterStep.searching, address: address),
          AddPrinterState(address: address, probeFailure: kind),
        ],
      );
    }

    blocTest<AddPrinterCubit, AddPrinterState>(
      'says when the device is not a printer',
      setUp: () => backend.device.device = (_) => const FakeAnswer(404),
      build: build,
      act: (cubit) => cubit.find('192.168.1.1'),
      skip: 1,
      expect: () => [
        const AddPrinterState(
          address: '192.168.1.1',
          probeFailure: ProbeFailureKind.notAPrinter,
        ),
      ],
    );

    test('ignores a second search while the first is out', () async {
      final gate = Completer<void>();
      backend.device.device = (request) async {
        await gate.future;
        throw PrinterUnreachable(request.uri, 'x');
      };
      final cubit = build();
      addTearDown(cubit.close);

      final first = cubit.find('192.168.1.40:631');
      await cubit.find('192.168.1.41:631');
      gate.complete();
      await first;

      expect(cubit.state.address, '192.168.1.40:631');
    });

    blocTest<AddPrinterCubit, AddPrinterState>(
      'startOver returns to the address that was tried',
      setUp: () => backend.plugInPrinter(),
      build: build,
      act: (cubit) async {
        await cubit.find('192.168.1.40');
        cubit.startOver();
      },
      skip: 2,
      expect: () => [const AddPrinterState(address: '192.168.1.40')],
    );
  });

  group('save', () {
    blocTest<AddPrinterCubit, AddPrinterState>(
      'adds the found device to the workspace',
      setUp: () => backend.plugInPrinter(),
      build: build,
      act: (cubit) async {
        await cubit.find('192.168.1.40');
        await cubit.save(name: 'Front desk', location: 'Lobby');
      },
      skip: 2,
      expect: () => [
        isA<AddPrinterState>().having(
          (s) => s.step,
          'step',
          AddPrinterStep.saving,
        ),
        isA<AddPrinterState>()
            .having((s) => s.step, 'step', AddPrinterStep.added)
            .having((s) => s.printer!.friendlyName, 'name', 'Front desk')
            .having((s) => s.printer!.location, 'location', 'Lobby')
            .having((s) => s.device, 'device', isNotNull),
      ],
      verify: (_) =>
          expect(backend.printerList.single['organization_id'], _org),
    );

    blocTest<AddPrinterCubit, AddPrinterState>(
      'returns to the name with why it could not be saved',
      setUp: () {
        backend
          ..plugInPrinter()
          ..fail(
            'POST /organizations/$_org/printers',
            403,
            'permission.denied',
          );
      },
      build: build,
      act: (cubit) async {
        await cubit.find('192.168.1.40');
        await cubit.save(name: 'Front desk');
      },
      skip: 3,
      expect: () => [
        isA<AddPrinterState>()
            .having((s) => s.step, 'step', AddPrinterStep.found)
            .having((s) => s.error, 'error', isA<ApiProblem>())
            .having((s) => s.device, 'device', isNotNull),
      ],
    );

    blocTest<AddPrinterCubit, AddPrinterState>(
      'does nothing before a device was found',
      build: build,
      act: (cubit) => cubit.save(name: 'Front desk'),
      expect: () => <AddPrinterState>[],
    );

    test('ignores a second save while the first is out', () async {
      backend.plugInPrinter();
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.find('192.168.1.40');

      await Future.wait([
        cubit.save(name: 'Front desk'),
        cubit.save(name: 'Front desk'),
      ]);

      expect(backend.printerList, hasLength(1));
    });
  });
}
