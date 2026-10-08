import 'dart:convert';

import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_store/local_store.dart';
import 'package:printer_protocols/printer_protocols.dart';
import 'package:printer_protocols/testing.dart';
import 'package:printers_repository/printers_repository.dart';

const _org = 'org-1';
const _printers = '/api/v1/organizations/$_org/printers';

final _device = DeviceDescription(
  host: '192.168.1.40',
  manufacturer: 'Xerox',
  model: 'VersaLink C7130',
  serialNumber: 'SN1',
  connections: [
    DeviceConnection(
      type: 'ipp',
      uri: Uri.parse('ipp://192.168.1.40:631/ipp/print'),
    ),
    DeviceConnection(
      type: 'escl',
      uri: Uri.parse('http://192.168.1.40:80/eSCL'),
    ),
  ],
  print: const PrintFeatures(
    color: true,
    duplexModes: ['one_sided', 'two_sided_long_edge', 'tumble'],
    documentFormats: ['application/pdf'],
    mediaSizes: ['iso_a4_210x297mm'],
    trays: ['tray-1'],
    maxCopies: 99,
    qualities: ['normal'],
    collation: true,
    airPrint: true,
  ),
  scan: const ScanFeatures(
    sources: ['platen', 'adf', 'camera'],
    feederDuplex: true,
    colorModes: ['color', 'sepia'],
    documentFormats: ['application/pdf'],
    resolutionsDpi: [300],
    maxWidthMm: 216,
    maxHeightMm: 297,
  ),
  status: const DeviceStatus(
    state: 'online',
    supplies: [
      Supply(name: 'Cyan Toner', kind: 'toner', color: 'cyan', levelPercent: 8),
    ],
    alerts: [DeviceAlert(code: 'toner-low', severity: 'warning')],
    scannerState: 'idle',
  ),
);

void main() {
  late FakeApi api;
  late FakePrinterHttp device;
  late InMemorySecureStore store;
  late PrintersRepository repository;

  Map<String, dynamic> bodyOf(RequestOptions request) {
    return jsonDecode(jsonEncode(request.data)) as Map<String, dynamic>;
  }

  setUp(() {
    api = FakeApi((request) async {
      if (request.method == 'GET') {
        return FakeResponse(200, {
          'items': [printerBody()],
          'next_cursor': null,
        });
      }
      if (request.method == 'DELETE') return const FakeResponse(204);
      return FakeResponse(request.method == 'POST' ? 201 : 200, printerBody());
    });
    device = FakePrinterHttp(
      (request) => throw PrinterUnreachable(request.uri, 'off'),
    );
    store = InMemorySecureStore();
    final client = PrinterHubClient(
      baseUrl: Uri.parse('https://api.example.com'),
      tokenStore: InMemoryTokenStore(),
      httpClientAdapter: api,
    );
    addTearDown(client.close);
    repository = PrintersRepository(
      client: client,
      probe: DeviceProbe(http: device),
      store: store,
    );
  });

  group('list', () {
    test('returns the workspace printers', () async {
      final printers = await repository.list(_org);

      expect(printers.single.friendlyName, 'Front desk');
      expect(api.requests.single.path, _printers);
    });

    test('follows the pages to the end', () async {
      api.handler = (request) async {
        final first = request.queryParameters['cursor'] == null;
        return FakeResponse(200, {
          'items': [printerBody(id: first ? 'a' : 'b')],
          'next_cursor': first ? 'page-2' : null,
        });
      };

      final printers = await repository.list(_org);

      expect(printers.map((printer) => printer.id), ['a', 'b']);
      expect(api.requests.last.queryParameters['cursor'], 'page-2');
    });

    test('answers from the last list when offline', () async {
      final online = await repository.list(_org);
      api.handler = (_) async => throw const FormatException('offline');

      final offline = await repository.list(_org);

      expect(offline.single.id, online.single.id);
      expect(offline.single.capabilities!.print.color, isTrue);
    });

    test('keeps each workspace apart', () async {
      await repository.list(_org);
      api.handler = (_) async => throw const FormatException('offline');

      await expectLater(
        repository.list('org-2'),
        throwsA(isA<ApiUnreachable>()),
      );
    });

    test('fails offline when the kept list cannot be read', () async {
      await store.write('printers.$_org', 'not json');
      api.handler = (_) async => throw const FormatException('offline');

      await expectLater(repository.list(_org), throwsA(isA<ApiUnreachable>()));
    });

    test('reports a refusal from the API', () async {
      api.handler = (_) async => FakeResponse.problem(403, 'permission.denied');

      await expectLater(repository.list(_org), throwsA(isA<ApiProblem>()));
    });

    test('clear forgets the kept lists', () async {
      await repository.list(_org);

      await repository.clear([_org]);

      expect(store.values, isEmpty);
    });
  });

  test('probe asks the device what it is', () async {
    await expectLater(
      repository.probe('192.168.1.99'),
      throwsA(
        isA<ProbeFailure>().having(
          (failure) => failure.kind,
          'kind',
          ProbeFailureKind.unreachable,
        ),
      ),
    );
  });

  test('probeAnnounced asks the device where it said it is', () async {
    await expectLater(
      repository.probeAnnounced(
        host: '192.168.1.40',
        ipp: Uri.parse('ipp://192.168.1.40:631/ipp/print'),
      ),
      throwsA(isA<ProbeFailure>()),
    );
    expect(device.requests.map((request) => request.uri.port), contains(631));
  });

  group('pairing', () {
    test('createPairingCode returns the link to show as a QR code', () async {
      api.handler = (_) async => const FakeResponse(201, {
        'payload': {
          'v': 1,
          'token': 'tok',
          'printer_id': 'printer-1',
          'organization_id': _org,
        },
        'deep_link': 'printerhub://pair?token=tok',
        'expires_at': '2026-10-07T10:05:00Z',
      });

      final code = await repository.createPairingCode(
        organizationId: _org,
        printerId: 'printer-1',
      );

      expect(code.link, 'printerhub://pair?token=tok');
      expect(code.expiresAt, DateTime.utc(2026, 10, 7, 10, 5));
      expect(api.requests.single.path, '$_printers/printer-1/pairing-tokens');
    });

    test('redeemPairingCode returns the printer the code names', () async {
      api.handler = (_) async => FakeResponse(200, {'printer': printerBody()});

      final printer = await repository.redeemPairingCode('tok');

      expect(printer.friendlyName, 'Front desk');
      expect(api.requests.single.path, '/api/v1/pairing/redeem');
      expect(bodyOf(api.requests.single), {'token': 'tok'});
    });

    test('redeemPairingCode reports a code that has expired', () async {
      api.handler = (_) async =>
          FakeResponse.problem(422, 'pairing.token_invalid');

      await expectLater(
        repository.redeemPairingCode('old'),
        throwsA(isA<ApiProblem>()),
      );
    });
  });

  group('add', () {
    test('sends what the device said about itself', () async {
      await repository.add(
        organizationId: _org,
        device: _device,
        name: 'Front desk',
        location: 'Second floor',
      );

      final body = bodyOf(api.requests.first);
      final capabilities = body['capabilities'] as Map<String, dynamic>;
      final print = capabilities['print'] as Map<String, dynamic>;
      final scan = capabilities['scan'] as Map<String, dynamic>;
      final connections = body['connections'] as List<dynamic>;

      expect(api.requests.first.path, _printers);
      expect(body['friendly_name'], 'Front desk');
      expect(body['location'], 'Second floor');
      expect(body['manufacturer'], 'Xerox');
      expect(body['model'], 'VersaLink C7130');
      expect(body['serial_number'], 'SN1');
      expect(print['supported'], isTrue);
      expect(print['color'], isTrue);
      expect(print['duplex_modes'], ['one_sided', 'two_sided_long_edge']);
      expect(print['max_copies'], 99);
      expect(print['trays'], [
        {'id': 'tray-1', 'name': 'tray-1'},
      ]);
      expect(scan['supported'], isTrue);
      expect(scan['sources'], ['platen', 'adf']);
      expect(scan['color_modes'], ['color']);
      expect(scan['adf_duplex'], isTrue);
      expect(capabilities['copy'], {
        'supported': true,
        'native_remote_control': false,
      });
      expect(capabilities['protocols'], {
        'ipp': true,
        'ipps': false,
        'escl': true,
        'airprint': true,
      });
      expect(capabilities['status'], {
        'reporting': true,
        'consumables': true,
        'trays': false,
      });
      expect(connections, [
        {
          'type': 'ipp',
          'purposes': ['print', 'status'],
          'priority': 1,
          'configuration': {
            'host': '192.168.1.40',
            'port': 631,
            'path': '/ipp/print',
            'tls': false,
          },
        },
        {
          'type': 'escl',
          'purposes': ['scan'],
          'priority': 2,
          'configuration': {
            'host': '192.168.1.40',
            'port': 80,
            'path': '/eSCL',
            'tls': false,
          },
        },
      ]);
    });

    test('then records what the device was doing', () async {
      await repository.add(
        organizationId: _org,
        device: _device,
        name: 'Front desk',
      );

      final report = bodyOf(api.requests.last);
      expect(api.requests.last.path, '$_printers/printer-1/status');
      expect(report['status'], 'online');
      expect(report['detail'], {
        'scanner_state': 'idle',
        'consumables': [
          {
            'name': 'Cyan Toner',
            'kind': 'toner',
            'color': 'cyan',
            'level_percent': 8,
            'state': 'low',
          },
        ],
        'alerts': [
          {'code': 'toner-low', 'severity': 'warning'},
        ],
      });
    });

    test('leaves out an empty location', () async {
      await repository.add(
        organizationId: _org,
        device: _device,
        name: 'Front desk',
        location: '  ',
      );

      expect(bodyOf(api.requests.first).containsKey('location'), isFalse);
    });

    test('describes a device that only prints', () async {
      await repository.add(
        organizationId: _org,
        device: DeviceDescription(
          host: 'p.local',
          connections: [
            DeviceConnection(
              type: 'ipps',
              uri: Uri.parse('ipps://p.local:631/ipp/print'),
            ),
          ],
          print: const PrintFeatures(),
        ),
        name: 'Laser',
      );

      final body = bodyOf(api.requests.first);
      final capabilities = body['capabilities'] as Map<String, dynamic>;
      expect(capabilities.containsKey('scan'), isFalse);
      expect(capabilities['copy'], {
        'supported': false,
        'native_remote_control': false,
      });
      expect(
        (capabilities['protocols'] as Map<String, dynamic>)['ipps'],
        isTrue,
      );
      expect(
        ((body['connections'] as List<dynamic>).single
            as Map<String, dynamic>)['configuration'],
        containsPair('tls', true),
      );
    });

    test('still adds the printer when its status cannot be recorded', () async {
      api.handler = (request) async => request.path.endsWith('/status')
          ? FakeResponse.problem(500, 'internal_error')
          : FakeResponse(201, printerBody());

      final printer = await repository.add(
        organizationId: _org,
        device: _device,
        name: 'Front desk',
      );

      expect(printer.id, 'printer-1');
    });

    test('reports why the printer could not be added', () async {
      api.handler = (_) async => FakeResponse.problem(409, 'printer.duplicate');

      await expectLater(
        repository.add(organizationId: _org, device: _device, name: 'x'),
        throwsA(isA<ApiProblem>()),
      );
    });
  });

  group('refreshStatus', () {
    final printer = PrinterRead.fromJson(printerBody().cast());

    test('asks the device and tells the backend', () async {
      device.device = (request) => request.uri.path.contains('eSCL')
          ? FakeAnswer.text(
              200,
              '<s:ScannerStatus xmlns:s="x" xmlns:pwg="y"><pwg:State>Idle</pwg:State></s:ScannerStatus>',
            )
          : FakeAnswer.ipp(
              ippResponse(
                groups: [
                  IppGroup(IppGroupTag.printer, [
                    IppAttribute.single(
                      'printer-state',
                      IppValueTag.enumeration,
                      3,
                    ),
                  ]),
                ],
              ),
            );
      api.handler = (_) async =>
          FakeResponse(200, printerBody(name: 'From API'));

      final result = await repository.refreshStatus(
        organizationId: _org,
        printer: printer,
      );

      expect(result.status.state, 'online');
      expect(result.status.scannerState, 'idle');
      expect(result.printer.friendlyName, 'From API');
      expect(device.requests.map((r) => r.uri.toString()), [
        'http://192.168.1.40:631/ipp/print',
        'http://192.168.1.40/eSCL/ScannerStatus',
      ]);
      expect(bodyOf(api.requests.single)['status'], 'online');
    });

    test('reports a device that does not answer as unreachable', () async {
      final result = await repository.refreshStatus(
        organizationId: _org,
        printer: printer,
      );

      expect(result.status, DeviceStatus.unreachable);
      expect(bodyOf(api.requests.single)['status'], 'unreachable');
    });

    test('keeps the status when the backend cannot be told', () async {
      api.handler = (_) async => throw const FormatException('offline');

      final result = await repository.refreshStatus(
        organizationId: _org,
        printer: printer,
      );

      expect(result.status, DeviceStatus.unreachable);
      expect(result.printer, same(printer));
    });
  });

  test('rename changes the name and location', () async {
    final renamed = await repository.rename(
      organizationId: _org,
      printerId: 'printer-1',
      name: 'Lobby',
      location: 'Ground floor',
    );

    expect(renamed.id, 'printer-1');
    expect(api.requests.single.method, 'PATCH');
    expect(bodyOf(api.requests.single), {
      'friendly_name': 'Lobby',
      'location': 'Ground floor',
    });
  });

  test('remove deletes the printer', () async {
    await repository.remove(organizationId: _org, printerId: 'printer-1');

    expect(api.requests.single.method, 'DELETE');
    expect(api.requests.single.path, '$_printers/printer-1');
  });

  group('connectionFromApi', () {
    ConnectionRead connection(Map<String, Object?> body) {
      return ConnectionRead.fromJson(body.cast());
    }

    test('rebuilds the address the device answers on', () {
      expect(
        connectionFromApi(connection(connectionBody()))!.uri,
        Uri.parse('ipp://192.168.1.40:631/ipp/print'),
      );
      expect(
        connectionFromApi(connection(connectionBody(type: 'ipps')))!.uri.scheme,
        'ipps',
      );
      expect(
        connectionFromApi(
          connection(connectionBody(type: 'escl', port: 80, path: '/eSCL')),
        )!.uri,
        Uri.parse('http://192.168.1.40/eSCL'),
      );
    });

    test('fills in what an older record left out', () {
      Map<String, Object?> bare(String type, {bool? tls}) => {
        ...connectionBody(type: type),
        'configuration': {
          'host': 'p.local',
          'port': null,
          'path': null,
          'tls': tls,
          'service_name': null,
          'ssid': null,
          'options': <String, Object?>{},
        },
      };

      expect(
        connectionFromApi(connection(bare('ipp')))!.uri,
        Uri.parse('ipp://p.local:631/ipp/print'),
      );
      expect(
        connectionFromApi(connection(bare('escl')))!.uri,
        Uri.parse('http://p.local/eSCL'),
      );
      expect(
        connectionFromApi(connection(bare('escl', tls: true)))!.uri,
        Uri.parse('https://p.local/eSCL'),
      );
    });

    test('is null for a connection the app does not open itself', () {
      expect(
        connectionFromApi(connection(connectionBody(type: 'airprint'))),
        isNull,
      );
      expect(connectionFromApi(connection(connectionBody(host: ''))), isNull);
    });
  });

  group('statusToApi', () {
    test('sends unknown for a state the API does not know', () {
      final report = statusToApi(
        const DeviceStatus(state: 'hibernating', scannerState: 'dreaming'),
      );

      expect(report.status, PrinterStatus.unknown);
      expect(
        report.detail!.scannerState,
        PrinterStatusDetailInputScannerState.unknown,
      );
    });
  });
}
