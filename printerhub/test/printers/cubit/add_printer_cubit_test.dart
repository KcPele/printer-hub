import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printer_discovery/printer_discovery.dart';
import 'package:printer_protocols/printer_protocols.dart';
import 'package:printer_protocols/testing.dart';
import 'package:printerhub/printers/printers.dart';
import 'package:printers_repository/printers_repository.dart';

import '../../helpers/helpers.dart';

const _org = 'org-1';

const _announced = NearbyDevice(
  name: 'Front desk printer',
  host: '192.168.1.40',
  model: 'Xerox VersaLink C7130',
);

void main() {
  late TestBackend backend;

  setUp(() => backend = TestBackend());
  tearDown(() => backend.close());

  AddPrinterCubit build() {
    return AddPrinterCubit(
      printersRepository: backend.printers,
      finders: backend.finders,
      organizationId: _org,
    );
  }

  TypeMatcher<AddPrinterState> onStep(AddPrinterStep step) {
    return isA<AddPrinterState>().having((s) => s.step, 'step', step);
  }

  test('starts on the ways to connect', () {
    final cubit = build();
    addTearDown(cubit.close);

    expect(cubit.state, const AddPrinterState());
    expect(cubit.state.step, AddPrinterStep.ways);
  });

  group('start', () {
    test('finds out which radios the phone has', () async {
      backend.bluetooth.available = false;
      final cubit = build();
      addTearDown(cubit.close);

      await cubit.start();

      expect(cubit.state.nfcAvailable, isTrue);
      expect(cubit.state.bluetoothAvailable, isFalse);
    });
  });

  blocTest<AddPrinterCubit, AddPrinterState>(
    'choose opens a way to connect, and back returns to the list',
    build: build,
    act: (cubit) => cubit
      ..choose(AddPrinterStep.address)
      ..back()
      ..choose(AddPrinterStep.qr),
    expect: () => [
      onStep(AddPrinterStep.address),
      onStep(AddPrinterStep.ways),
      onStep(AddPrinterStep.qr),
    ],
  );

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
        onStep(AddPrinterStep.found)
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
          AddPrinterState(
            step: AddPrinterStep.address,
            address: address,
            probeFailure: kind,
          ),
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
          step: AddPrinterStep.address,
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
      await cubit.findOnThisNetwork();
      await cubit.useCode('192.168.1.42');
      await cubit.readNfc();
      gate.complete();
      await first;

      expect(cubit.state.address, '192.168.1.40:631');
    });

    blocTest<AddPrinterCubit, AddPrinterState>(
      'a message does not outlive the attempt that caused it',
      build: build,
      act: (cubit) async {
        await cubit.find('192.168.1.99');
        cubit.back();
      },
      skip: 2,
      expect: () => [const AddPrinterState(address: '192.168.1.99')],
    );
  });

  group('findNearby', () {
    blocTest<AddPrinterCubit, AddPrinterState>(
      'asks a printer that announced itself what it is',
      setUp: () => backend.plugInPrinter(),
      build: build,
      act: (cubit) => cubit.findNearby(_announced),
      skip: 1,
      expect: () => [onStep(AddPrinterStep.found)],
    );

    blocTest<AddPrinterCubit, AddPrinterState>(
      'returns to the list when the printer has gone',
      build: build,
      act: (cubit) => cubit.findNearby(_announced),
      skip: 1,
      expect: () => [
        const AddPrinterState(probeFailure: ProbeFailureKind.unreachable),
      ],
    );
  });

  group('findOnThisNetwork', () {
    blocTest<AddPrinterCubit, AddPrinterState>(
      'looks for the printer at the gateway of its own Wi-Fi',
      setUp: () {
        backend
          ..plugInPrinter()
          ..wifi.gateway = '192.168.223.1';
      },
      build: build,
      act: (cubit) => cubit.findOnThisNetwork(),
      skip: 1,
      expect: () => [
        onStep(AddPrinterStep.found)
            .having((s) => s.device!.host, 'host', '192.168.223.1'),
      ],
    );

    blocTest<AddPrinterCubit, AddPrinterState>(
      'says when the phone is not on the printer network',
      build: build,
      act: (cubit) => cubit.findOnThisNetwork(),
      expect: () => [
        const AddPrinterState(
          step: AddPrinterStep.wifiDirect,
          notice: AddPrinterNotice.notOnPrinterNetwork,
        ),
      ],
    );

    blocTest<AddPrinterCubit, AddPrinterState>(
      'returns to the steps when nothing is at the gateway',
      setUp: () => backend.wifi.gateway = '192.168.223.1',
      build: build,
      act: (cubit) => cubit.findOnThisNetwork(),
      skip: 1,
      expect: () => [
        const AddPrinterState(
          step: AddPrinterStep.wifiDirect,
          probeFailure: ProbeFailureKind.unreachable,
        ),
      ],
    );
  });

  group('pickSighting', () {
    const sighting = BluetoothSighting(
      id: '1',
      name: 'Xerox C7130',
      signal: -40,
    );

    blocTest<AddPrinterCubit, AddPrinterState>(
      'reaches the printer seen over Bluetooth through the network',
      setUp: () => backend.plugInPrinter(),
      build: build,
      act: (cubit) => cubit.pickSighting(sighting, const [_announced]),
      skip: 1,
      expect: () => [onStep(AddPrinterStep.found)],
    );

    blocTest<AddPrinterCubit, AddPrinterState>(
      'says when the printer is near but not on the network',
      build: build,
      act: (cubit) => cubit.pickSighting(sighting, const []),
      expect: () => [
        const AddPrinterState(
          step: AddPrinterStep.bluetooth,
          notice: AddPrinterNotice.seenButNotOnNetwork,
          noticeSubject: 'Xerox C7130',
        ),
      ],
    );
  });

  group('useCode', () {
    blocTest<AddPrinterCubit, AddPrinterState>(
      'opens the printer a pairing code names',
      setUp: () => backend.printerList = [printerBody()],
      build: build,
      act: (cubit) => cubit.useCode('printerhub://pair?token=token-printer-1'),
      expect: () => [
        onStep(AddPrinterStep.searching),
        onStep(AddPrinterStep.paired)
            .having((s) => s.printer!.friendlyName, 'printer', 'Front desk'),
      ],
    );

    blocTest<AddPrinterCubit, AddPrinterState>(
      'says when a pairing code has expired',
      build: build,
      seed: () => const AddPrinterState(step: AddPrinterStep.qr),
      act: (cubit) => cubit.useCode('printerhub://pair?token=old'),
      skip: 1,
      expect: () => [
        onStep(AddPrinterStep.qr).having(
          (s) => (s.error! as ApiProblem).code,
          'code',
          'pairing.token_invalid',
        ),
      ],
    );

    blocTest<AddPrinterCubit, AddPrinterState>(
      'looks for the printer at a scanned address',
      setUp: () => backend.plugInPrinter(),
      build: build,
      seed: () => const AddPrinterState(step: AddPrinterStep.qr),
      act: (cubit) => cubit.useCode('ipp://192.168.1.40:631/ipp/print'),
      expect: () => [
        onStep(AddPrinterStep.searching).having(
          (s) => s.address,
          'address',
          'ipp://192.168.1.40:631/ipp/print',
        ),
        onStep(AddPrinterStep.found),
      ],
    );

    blocTest<AddPrinterCubit, AddPrinterState>(
      'returns to the camera when the scanned address finds nothing',
      build: build,
      seed: () => const AddPrinterState(step: AddPrinterStep.qr),
      act: (cubit) => cubit.useCode('192.168.1.99'),
      skip: 1,
      expect: () => [
        onStep(AddPrinterStep.qr).having(
          (s) => s.probeFailure,
          'failure',
          ProbeFailureKind.unreachable,
        ),
      ],
    );

    blocTest<AddPrinterCubit, AddPrinterState>(
      'shows how to join a printer network that was scanned',
      build: build,
      act: (cubit) => cubit.useCode('WIFI:T:WPA;S:DIRECT-AB-C7130;P:secret;;'),
      expect: () => [
        onStep(AddPrinterStep.wifiDirect).having(
          (s) => s.wifi,
          'wifi',
          const WifiNetworkCode(ssid: 'DIRECT-AB-C7130', password: 'secret'),
        ),
      ],
    );

    blocTest<AddPrinterCubit, AddPrinterState>(
      'says when the code is something else',
      build: build,
      seed: () => const AddPrinterState(step: AddPrinterStep.qr),
      act: (cubit) => cubit.useCode('https://example.com/manual.pdf'),
      expect: () => [
        // A web link is an address, so it is tried; nothing answers there.
        onStep(AddPrinterStep.searching),
        onStep(AddPrinterStep.qr),
      ],
    );

    blocTest<AddPrinterCubit, AddPrinterState>(
      'says when the code is not readable at all',
      build: build,
      seed: () => const AddPrinterState(step: AddPrinterStep.qr),
      act: (cubit) => cubit.useCode('SN-0042-XYZ'),
      expect: () => [
        const AddPrinterState(
          step: AddPrinterStep.qr,
          notice: AddPrinterNotice.codeNotRecognised,
        ),
      ],
    );
  });

  group('readNfc', () {
    test('acts on what the tag holds', () async {
      backend.plugInPrinter();
      final cubit = build();
      addTearDown(cubit.close);

      final reading = cubit.readNfc();
      expect(cubit.state.readingNfc, isTrue);
      backend.nfc.tap('192.168.1.40');
      await reading;

      expect(cubit.state.step, AddPrinterStep.found);
      expect(cubit.state.readingNfc, isFalse);
    });

    test('says when the tag holds nothing readable', () async {
      final cubit = build();
      addTearDown(cubit.close);

      final reading = cubit.readNfc();
      backend.nfc.tap(null);
      await reading;

      expect(cubit.state.notice, AddPrinterNotice.nfcNothing);
      expect(cubit.state.readingNfc, isFalse);
    });

    test('says when the tag could not be read', () async {
      final cubit = build();
      addTearDown(cubit.close);

      final reading = cubit.readNfc();
      backend.nfc.fail(StateError('tag lost'));
      await reading;

      expect(cubit.state.notice, AddPrinterNotice.nfcFailed);
    });

    test('does not wait twice at once', () async {
      final cubit = build();
      addTearDown(cubit.close);

      final first = cubit.readNfc();
      await cubit.readNfc();
      backend.nfc.tap(null);
      await first;

      expect(cubit.state.notice, AddPrinterNotice.nfcNothing);
    });

    test('can be cancelled, and then ignores a late tag or failure', () async {
      final cubit = build();
      addTearDown(cubit.close);

      final reading = cubit.readNfc();
      await cubit.cancelNfc();
      expect(cubit.state.readingNfc, isFalse);
      expect(backend.nfc.cancelled, isTrue);
      backend.nfc.tap('192.168.1.40');
      await reading;
      expect(cubit.state, const AddPrinterState());

      final failing = cubit.readNfc();
      await cubit.cancelNfc();
      backend.nfc.fail(StateError('cancelled'));
      await failing;
      expect(cubit.state.notice, isNull);

      await cubit.cancelNfc();
      expect(cubit.state, const AddPrinterState());
    });
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
        onStep(AddPrinterStep.saving),
        onStep(AddPrinterStep.added)
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
        onStep(AddPrinterStep.found)
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

  group('the lists of what is around', () {
    test('NearbyPrintersCubit follows the network', () async {
      final cubit = NearbyPrintersCubit(discovery: backend.nearby);
      await pumpEventQueue();
      expect(cubit.state, isEmpty);
      expect(backend.nearby.listeners, 1);

      backend.nearby.announce(const [_announced]);
      await pumpEventQueue();
      expect(cubit.state, const [_announced]);

      await cubit.close();
      expect(backend.nearby.listeners, 0);
    });

    test('NearbyPrintersCubit shows nothing when discovery fails', () async {
      final cubit = NearbyPrintersCubit(discovery: _BrokenDiscovery());
      addTearDown(cubit.close);

      await pumpEventQueue();

      expect(cubit.state, isEmpty);
    });

    test('BluetoothSightingsCubit follows the radio', () async {
      final cubit = BluetoothSightingsCubit(scanner: backend.bluetooth);
      await pumpEventQueue();

      backend.bluetooth.see(const [
        BluetoothSighting(id: '1', name: 'Far', signal: -90),
        BluetoothSighting(id: '2', name: 'Near', signal: -40),
      ]);
      await pumpEventQueue();

      expect(cubit.state.map((s) => s.name), ['Near', 'Far']);
      await cubit.close();
    });

    test('BluetoothSightingsCubit shows nothing when scanning fails', () async {
      final cubit = BluetoothSightingsCubit(scanner: _BrokenScanner());
      addTearDown(cubit.close);

      await pumpEventQueue();

      expect(cubit.state, isEmpty);
    });
  });
}

class _BrokenDiscovery implements NetworkDiscovery {
  @override
  Stream<List<NearbyDevice>> watch() => Stream.error(StateError('no Wi-Fi'));
}

class _BrokenScanner implements BluetoothScanner {
  @override
  Future<bool> get isAvailable async => true;

  @override
  Stream<List<BluetoothSighting>> scan() => Stream.error(StateError('off'));
}
