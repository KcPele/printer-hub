import 'dart:convert';
import 'dart:io';

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
  late Directory scans;

  Map<String, dynamic> bodyOf(RequestOptions request) {
    return jsonDecode(jsonEncode(request.data)) as Map<String, dynamic>;
  }

  setUp(() {
    scans = Directory.systemTemp.createTempSync('printers_repository_test');
    addTearDown(() => scans.deleteSync(recursive: true));
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
      runner: PrintRunner(http: device, pause: (_) async {}),
      scanner: ScanRunner(http: device, directory: scans),
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

  group('the catalogue', () {
    void serve(List<Map<String, Object?>> profiles) {
      api.handler = (_) async => FakeResponse(200, profiles);
    }

    test('lists the families, as the API orders them', () async {
      serve([
        profileBody(),
        profileBody(
          id: 'profile-2',
          manufacturer: 'Epson',
          name: 'EcoTank',
          category: 'home_multifunction',
          summary: null,
          color: false,
          scans: false,
        ),
      ]);

      final families = await repository.families();

      expect(families.map((family) => family.title), [
        'Xerox VersaLink C7100 Series',
        'Epson EcoTank',
      ]);
      final xerox = families.first;
      expect(xerox.category, 'office_multifunction');
      expect(xerox.isHome, isFalse);
      expect(xerox.summary, startsWith('A3 colour'));
      expect(xerox.setupTips, hasLength(2));
      expect([
        xerox.color,
        xerox.duplex,
        xerox.scans,
        xerox.feeder,
      ], everyElement(isTrue));
      final epson = families.last;
      expect(epson.isHome, isTrue);
      expect([epson.color, epson.scans, epson.feeder], everyElement(isFalse));
      expect(api.requests.single.path, '/api/v1/capability-profiles');
    });

    test('answers from the last read when offline', () async {
      serve([profileBody()]);
      await repository.families();
      api.handler = (_) async => throw const FormatException('offline');

      expect((await repository.families()).single.name, contains('C7100'));
    });

    test('fails offline when nothing was kept, or it cannot be read', () async {
      api.handler = (_) async => throw const FormatException('offline');
      await expectLater(repository.families(), throwsA(isA<ApiUnreachable>()));

      store.values['catalogue'] = 'not json';
      await expectLater(repository.families(), throwsA(isA<ApiUnreachable>()));
    });

    test('a family is found by its name, its maker, or what it is for', () {
      final family = PrinterFamily.fromApi(
        CapabilityProfileRead.fromJson(profileBody().cast()),
      );

      expect(family.matches(''), isTrue);
      expect(family.matches('xerox'), isTrue);
      expect(family.matches('versalink XEROX'), isTrue);
      expect(family.matches('busy office'), isTrue);
      expect(family.matches('epson'), isFalse);
      expect(
        family,
        PrinterFamily.fromApi(
          CapabilityProfileRead.fromJson(profileBody().cast()),
        ),
      );
    });

    test('finds the family a printer belongs to', () async {
      api.handler = (_) async => FakeResponse(200, profileBody());

      final family = await repository.familyOf(
        manufacturer: 'Xerox',
        model: 'VersaLink C7130',
      );

      expect(family!.name, 'VersaLink C7100 Series');
      expect(api.requests.single.path, '/api/v1/capability-profiles/match');
      expect(api.requests.single.queryParameters, {
        'manufacturer': 'Xerox',
        'model': 'VersaLink C7130',
      });
    });

    test('asks under the name the catalogue knows a maker by', () async {
      api.handler = (_) async => FakeResponse(200, profileBody());

      await repository.familyOf(
        manufacturer: 'Hewlett-Packard',
        model: 'LaserJet Pro M404dn',
      );

      expect(api.requests.single.queryParameters['manufacturer'], 'HP');
    });

    test('has no family for a printer the catalogue does not know', () async {
      api.handler = (_) async => const FakeResponse(404, {
        'type': 'about:blank',
        'title': 'Not Found',
        'status': 404,
        'code': 'capability_profile.no_match',
        'detail': 'No capability profile matches this printer.',
      });

      expect(
        await repository.familyOf(manufacturer: 'Acme', model: 'Inkwell'),
        isNull,
      );
      // Nothing to ask about a printer that does not say what it is.
      api.requests.clear();
      expect(await repository.familyOf(manufacturer: null, model: 'x'), isNull);
      expect(await repository.familyOf(manufacturer: 'x', model: null), isNull);
      expect(api.requests, isEmpty);
    });
  });

  group('a printer that asks who is printing', () {
    const credentials = PrinterCredentials(userName: 'ada', password: 'pw');
    const path =
        '$_printers/printer-1/connections/connection-ipp-1/credentials';
    final locked = PrinterRead.fromJson(
      printerBody(connections: [connectionBody(hasCredentials: true)]).cast(),
    );

    /// A printer that answers only a signed request.
    void lockDevice() {
      device.device = (request) => request.headers['Authorization'] == null
          ? const FakeAnswer(
              401,
              headers: {'www-authenticate': 'Digest realm="x", nonce="n"'},
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
    }

    void serveCredentials({String? password = 'pw'}) {
      api.handler = (request) async => request.path.endsWith('/credentials')
          ? FakeResponse(200, {
              'username': 'ada',
              'password': password,
              'extra': <String, String>{},
            })
          : FakeResponse(200, printerBody());
    }

    test('is probed with the password it is given', () async {
      lockDevice();

      await expectLater(
        repository.probe('192.168.1.40'),
        throwsA(
          isA<ProbeFailure>().having(
            (failure) => failure.kind,
            'kind',
            ProbeFailureKind.needsPassword,
          ),
        ),
      );
      final found = await repository.probe(
        '192.168.1.40',
        credentials: credentials,
      );
      expect(found.connections.single.type, 'ipp');

      final announced = await repository.probeAnnounced(
        host: '192.168.1.40',
        ipp: Uri.parse('ipp://192.168.1.40:631/ipp/print'),
        credentials: credentials,
      );
      expect(announced.connections.single.type, 'ipp');
    });

    test('is saved with its password on the connections that print', () async {
      await repository.add(
        organizationId: _org,
        device: _device,
        name: 'Front desk',
        credentials: credentials,
      );

      final connections =
          bodyOf(api.requests.first)['connections'] as List<dynamic>;
      expect((connections[0] as Map)['credentials'], {
        'username': 'ada',
        'password': 'pw',
      });
      expect((connections[1] as Map)['type'], 'escl');
      expect((connections[1] as Map).containsKey('credentials'), isFalse);
    });

    test('has its password read once, then kept on the phone', () async {
      serveCredentials();

      final first = await repository.credentialsFor(
        organizationId: _org,
        printer: locked,
      );
      final second = await repository.credentialsFor(
        organizationId: _org,
        printer: locked,
      );

      expect(first!.userName, 'ada');
      expect(first.password, 'pw');
      expect(second!.password, 'pw');
      // The backend records every read, so it is asked once.
      expect(api.requests.map((request) => request.path), [path]);
    });

    test('has its password read again when asked afresh', () async {
      serveCredentials();
      await repository.credentialsFor(organizationId: _org, printer: locked);
      serveCredentials(password: 'changed');

      final fresh = await repository.credentialsFor(
        organizationId: _org,
        printer: locked,
        fresh: true,
      );

      expect(fresh!.password, 'changed');
      expect(
        (await repository.credentialsFor(
          organizationId: _org,
          printer: locked,
        ))!.password,
        'changed',
      );
    });

    test('has none when it asks for none', () async {
      expect(
        await repository.credentialsFor(
          organizationId: _org,
          printer: PrinterRead.fromJson(printerBody().cast()),
        ),
        isNull,
      );
      expect(api.requests, isEmpty);
    });

    test('has none when the member may not use it, or offline', () async {
      api.handler = (_) async => const FakeResponse(403, {
        'type': 'about:blank',
        'title': 'Forbidden',
        'status': 403,
        'code': 'auth.permission_denied',
        'detail': 'no',
      });
      expect(
        await repository.credentialsFor(organizationId: _org, printer: locked),
        isNull,
      );

      api.handler = (_) async => throw const FormatException('offline');
      expect(
        await repository.credentialsFor(organizationId: _org, printer: locked),
        isNull,
      );
    });

    test('has none when the stored ones are incomplete', () async {
      serveCredentials(password: null);

      expect(
        await repository.credentialsFor(organizationId: _org, printer: locked),
        isNull,
      );
    });

    test(
      'ignores kept passwords it cannot read, and forgets on clear',
      () async {
        store.values['printer-credentials.$_org'] = 'not json';
        serveCredentials();

        expect(
          await repository.credentialsFor(
            organizationId: _org,
            printer: locked,
          ),
          isNotNull,
        );
        expect(store.values['printer-credentials.$_org'], contains('ada'));

        await repository.clear([_org]);
        expect(store.values, isEmpty);
      },
    );

    test('has its status read with the password', () async {
      lockDevice();
      serveCredentials();

      final result = await repository.refreshStatus(
        organizationId: _org,
        printer: locked,
      );

      expect(result.status.state, 'online');
      expect(
        device.requests.last.headers['Authorization'],
        startsWith('Digest username="ada"'),
      );
    });
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
      expect(
        device.requests.map((r) => r.uri.toString()),
        unorderedEquals([
          'http://192.168.1.40:631/ipp/print',
          'http://192.168.1.40/eSCL/ScannerStatus',
        ]),
      );
      expect(bodyOf(api.requests.last)['status'], 'online');
    });

    test(
      'tells the backend how each connection did, when that changed',
      () async {
        device.device = (request) => request.uri.path.contains('eSCL')
            ? const FakeAnswer(404)
            : FakeAnswer.ipp(ippResponse());
        api.handler = (_) async => FakeResponse(200, printerBody());

        await repository.refreshStatus(organizationId: _org, printer: printer);

        final health = {
          for (final request in api.requests)
            if (request.path.endsWith('/health'))
              request.path.split('/').reversed.elementAt(1): bodyOf(request),
        };
        expect(health.keys, {'connection-ipp-1', 'connection-escl-2'});
        expect(health['connection-ipp-1']!['health'], 'connected');
        expect(health['connection-ipp-1']!['latency_ms'], isNonNegative);
        expect(health['connection-ipp-1']!.containsKey('error'), isFalse);
        expect(health['connection-escl-2']!['health'], 'config_required');
        expect(health['connection-escl-2']!['error'], contains('HTTP 404'));
        // Health first, so the printer that comes back carries it.
        expect(api.requests.last.path, endsWith('/status'));
      },
    );

    test('says nothing of a connection that is as it was', () async {
      final steady = PrinterRead.fromJson(
        printerBody(
          connections: [
            {...connectionBody(), 'health': 'unavailable'},
          ],
        ).cast(),
      );

      await repository.refreshStatus(organizationId: _org, printer: steady);

      expect(api.requests.single.path, endsWith('/status'));
    });

    test('keeps a long error short, and survives a refused report', () async {
      device.device = (request) =>
          throw PrinterUnreachable(request.uri, 'x' * 900);
      api.handler = (request) async => request.path.endsWith('/health')
          ? throw const FormatException('offline')
          : FakeResponse(200, printerBody());

      final result = await repository.refreshStatus(
        organizationId: _org,
        printer: printer,
      );

      expect(result.status, DeviceStatus.unreachable);
      final sent = api.requests.firstWhere((r) => r.path.endsWith('/health'));
      expect((bodyOf(sent)['error'] as String).length, 500);
    });

    test('reports a device that does not answer as unreachable', () async {
      final result = await repository.refreshStatus(
        organizationId: _org,
        printer: printer,
      );

      expect(result.status, DeviceStatus.unreachable);
      expect(bodyOf(api.requests.last)['status'], 'unreachable');
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

  group('connections', () {
    final printer = PrinterRead.fromJson(printerBody().cast());
    const base = '$_printers/printer-1';

    test('get reads one printer', () async {
      api.handler = (_) async => FakeResponse(200, printerBody(name: 'Fresh'));

      final read = await repository.get(
        organizationId: _org,
        printerId: 'printer-1',
      );

      expect(read.friendlyName, 'Fresh');
      expect(api.requests.single.method, 'GET');
      expect(api.requests.single.path, base);
    });

    test('recheck asks the printer again and records what it can do', () async {
      device.device = (request) => request.uri.path.contains('eSCL')
          ? const FakeAnswer(404)
          : FakeAnswer.ipp(
              ippResponse(
                groups: [
                  IppGroup(IppGroupTag.printer, [
                    IppAttribute.single(
                      'color-supported',
                      IppValueTag.boolean,
                      false,
                    ),
                  ]),
                ],
              ),
            );
      api.handler = (_) async => FakeResponse(200, printerBody(scans: false));

      final updated = await repository.recheck(
        organizationId: _org,
        printer: printer,
      );

      expect(updated.capabilities!.scan.supported, isFalse);
      final sent = api.requests.single;
      expect(sent.method, 'PUT');
      expect(sent.path, '$base/capabilities');
      expect((bodyOf(sent)['print'] as Map)['color'], isFalse);
      expect(bodyOf(sent).containsKey('scan'), isFalse);
      // It was asked where it is known to be, not searched for.
      expect(device.requests.map((r) => r.uri.toString()).toSet(), {
        'http://192.168.1.40:631/ipp/print',
        'http://192.168.1.40/eSCL/ScannerCapabilities',
      });
    });

    test('recheck leaves the record alone when the printer is away', () async {
      await expectLater(
        repository.recheck(organizationId: _org, printer: printer),
        throwsA(isA<ProbeFailure>()),
      );
      expect(api.requests, isEmpty);
    });

    test('lists a printer’s connections', () async {
      api.handler = (_) async => FakeResponse(200, [connectionBody()]);

      final listed = await repository.connections(
        organizationId: _org,
        printerId: 'printer-1',
      );

      expect(listed.single.id, 'connection-ipp-1');
      expect(api.requests.single.path, '$base/connections');
    });

    test('sets the order connections are tried in', () async {
      api.handler = (_) async => FakeResponse(200, [
        connectionBody(type: 'escl', port: 80, path: '/eSCL'),
        connectionBody(priority: 2),
      ]);

      final ordered = await repository.setConnectionOrder(
        organizationId: _org,
        printerId: 'printer-1',
        connectionIds: ['connection-escl-2', 'connection-ipp-1'],
      );

      expect(ordered.first.type, ConnectionType.escl);
      expect(api.requests.single.method, 'PUT');
      expect(api.requests.single.path, '$base/connections/priority');
      expect(bodyOf(api.requests.single), {
        'connection_ids': ['connection-escl-2', 'connection-ipp-1'],
      });
    });

    test('removes a connection', () async {
      api.handler = (_) async => const FakeResponse(204);

      await repository.removeConnection(
        organizationId: _org,
        printerId: 'printer-1',
        connectionId: 'connection-escl-2',
      );

      expect(api.requests.single.method, 'DELETE');
      expect(api.requests.single.path, '$base/connections/connection-escl-2');
    });

    test('adds only the ways in that the printer does not have', () async {
      api.handler = (_) async => FakeResponse(201, connectionBody());
      final moved = DeviceDescription(
        host: '192.168.1.77',
        connections: [
          // Already saved.
          _device.connections.first,
          DeviceConnection(
            type: 'ipps',
            uri: Uri.parse('ipps://192.168.1.77:631/ipp/print'),
          ),
        ],
      );

      final added = await repository.addConnections(
        organizationId: _org,
        printer: printer,
        device: moved,
        credentials: const PrinterCredentials(userName: 'ada', password: 'pw'),
      );

      expect(added, 1);
      final sent = bodyOf(api.requests.single);
      expect(api.requests.single.path, '$base/connections');
      expect(sent['type'], 'ipps');
      expect((sent['configuration'] as Map)['host'], '192.168.1.77');
      // Last in line: what works now stays first.
      expect(sent.containsKey('priority'), isFalse);
      expect((sent['credentials'] as Map)['username'], 'ada');
    });

    test('replaces a connection’s password, here and on the backend', () async {
      api.handler = (_) async =>
          FakeResponse(200, connectionBody(hasCredentials: true));
      final connection = ConnectionRead.fromJson(connectionBody().cast());

      final updated = await repository.setCredentials(
        organizationId: _org,
        connection: connection,
        credentials: const PrinterCredentials(userName: 'ada', password: 'new'),
      );

      expect(updated.hasCredentials, isTrue);
      expect(api.requests.single.method, 'PATCH');
      expect(bodyOf(api.requests.single), {
        'credentials': {'username': 'ada', 'password': 'new'},
      });
      // The phone uses the new one at once, without asking the backend.
      api.requests.clear();
      final kept = await repository.credentialsFor(
        organizationId: _org,
        printer: PrinterRead.fromJson(
          printerBody(connections: [connectionBody(hasCredentials: true)])
              .cast(),
        ),
      );
      expect(kept!.password, 'new');
      expect(api.requests, isEmpty);
    });
  });

  group('fate', () {
    /// A printer that has one finished job, numbered 7.
    FakeAnswer printer(SentRequest request) {
      final asked = decodeIpp(request.body).message;
      final wanted = asked.group(IppGroupTag.operation)!['job-id']?.first;
      return FakeAnswer.ipp(
        ippResponse(
          status: asked.code == IppOperation.getJobAttributes && wanted != 7
              ? IppStatus.clientErrorNotFound
              : IppStatus.ok,
          groups: [
            if (wanted == 7)
              IppGroup(IppGroupTag.job, [
                IppAttribute.single('job-id', IppValueTag.integer, 7),
                IppAttribute.single('job-state', IppValueTag.enumeration, 9),
              ]),
          ],
        ),
      );
    }

    test('asks the printer what became of a print, by its number', () async {
      device.device = printer;
      final saved = PrinterRead.fromJson(printerBody().cast());

      final fate = await repository.fate(
        organizationId: _org,
        printer: saved,
        title: 'Report.pdf',
        reference: 'ab12',
        printerJobRef: '7',
      );

      expect(fate!.stage, PrintStage.completed);
      // Only the printing connection is asked.
      expect(device.requests.map((r) => r.uri.port).toSet(), {631});
    });

    test('says a print never arrived when the printer has nothing by its '
        'name', () async {
      device.device = printer;
      final saved = PrinterRead.fromJson(printerBody().cast());

      final fate = await repository.fate(
        organizationId: _org,
        printer: saved,
        title: 'Report.pdf',
        reference: 'ab12',
      );

      expect(fate!.errorCode, 'print.interrupted');
    });

    test('has no answer when the printer cannot be reached', () async {
      final saved = PrinterRead.fromJson(printerBody().cast());

      expect(
        await repository.fate(
          organizationId: _org,
          printer: saved,
          title: 'Report.pdf',
          reference: 'ab12',
          printerJobRef: 'not-a-number',
        ),
        isNull,
      );
    });
  });

  group('scan', () {
    const namespaces =
        'xmlns:scan="http://schemas.hp.com/imaging/escl/2011/05/03" '
        'xmlns:pwg="http://www.pwg.org/schemas/2010/12/sm"';

    /// A scanner with a glass, which gives one page and then no more.
    FakeDevice scanner() {
      var served = false;
      return (request) {
        final path = request.uri.path;
        if (path.endsWith('ScannerCapabilities')) {
          return FakeAnswer.text(
            200,
            [
              '<scan:ScannerCapabilities $namespaces><scan:Platen>',
              '<scan:PlatenInputCaps><scan:ColorMode>RGB24</scan:ColorMode>',
              '</scan:PlatenInputCaps></scan:Platen>',
              '</scan:ScannerCapabilities>',
            ].join(),
          );
        }
        if (path.endsWith('ScanJobs')) {
          return const FakeAnswer(
            201,
            headers: {'location': '/eSCL/ScanJobs/1'},
          );
        }
        if (request.method == 'DELETE' || served) return const FakeAnswer(404);
        served = true;
        return FakeAnswer.text(200, 'a page');
      };
    }

    test('scans over the saved connections, and names the one used', () async {
      device.device = scanner();
      final saved = PrinterRead.fromJson(printerBody().cast());

      final scan = repository.scan(
        printer: saved,
        request: const ScanRequest(),
      );
      final steps = await scan.progress.toList();

      expect(steps.last.stage, ScanStage.completed);
      expect(steps.last.pages.single.file.readAsStringSync(), 'a page');
      expect(scan.connectionIdOf(steps.last.connection), 'connection-escl-2');
      expect(scan.connectionIdOf(null), isNull);
      // The printing connection is not a way to scan.
      expect(device.requests.map((r) => r.uri.scheme).toSet(), {'http'});
    });

    test('can be cancelled', () async {
      device.device = scanner();
      final saved = PrinterRead.fromJson(printerBody().cast());

      final scan = repository.scan(
        printer: saved,
        request: const ScanRequest(),
      );
      await scan.cancel();

      expect((await scan.progress.toList()).last.stage, ScanStage.cancelled);
    });
  });

  group('print', () {
    final document = PrintDocument(
      name: 'Report.pdf',
      mimeType: 'application/pdf',
      length: 4,
      open: () => Stream.value([37, 80, 68, 70]),
    );

    /// A printer that reads PDF and finishes a job as soon as it is asked.
    FakeAnswer printer(SentRequest request) {
      final operation = decodeIpp(request.body).message.code;
      return FakeAnswer.ipp(
        ippResponse(
          groups: [
            if (operation == IppOperation.getPrinterAttributes)
              IppGroup(IppGroupTag.printer, [
                IppAttribute.single(
                  'document-format-supported',
                  IppValueTag.mimeMediaType,
                  'application/pdf',
                ),
              ])
            else
              IppGroup(IppGroupTag.job, [
                IppAttribute.single('job-id', IppValueTag.integer, 3),
                IppAttribute.single('job-state', IppValueTag.enumeration, 9),
              ]),
          ],
        ),
      );
    }

    test('prints over the saved connections, and names the one used', () async {
      device.device = printer;
      final saved = PrinterRead.fromJson(printerBody().cast());

      final print = await repository.print(
        organizationId: _org,
        printer: saved,
        document: document,
        request: const PrintRequest(),
        reference: 'ab12',
      );
      final steps = await print.progress.toList();

      expect(steps.last.stage, PrintStage.completed);
      expect(print.connectionIdOf(steps.last.connection), 'connection-ipp-1');
      expect(print.connectionIdOf(null), isNull);
      // The scanning connection is not a way to print.
      expect(device.requests.map((r) => r.uri.port).toSet(), {631});
    });

    test('signs in with the password kept for the printer', () async {
      device.device = (request) => request.headers['Authorization'] == null
          ? const FakeAnswer(
              401,
              headers: {'www-authenticate': 'Digest realm="x", nonce="n"'},
            )
          : printer(request);
      api.handler = (_) async => const FakeResponse(200, {
        'username': 'ada',
        'password': 'pw',
        'extra': <String, String>{},
      });

      final print = await repository.print(
        organizationId: _org,
        printer: PrinterRead.fromJson(
          printerBody(connections: [connectionBody(hasCredentials: true)])
              .cast(),
        ),
        document: document,
        request: const PrintRequest(),
        reference: 'ab12',
      );

      expect((await print.progress.toList()).last.stage, PrintStage.completed);
    });

    test('can be cancelled', () async {
      device.device = printer;

      final print = await repository.print(
        organizationId: _org,
        printer: PrinterRead.fromJson(printerBody().cast()),
        document: document,
        request: const PrintRequest(),
        reference: 'ab12',
      );
      await print.cancel();

      expect((await print.progress.toList()).last.stage, PrintStage.cancelled);
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
