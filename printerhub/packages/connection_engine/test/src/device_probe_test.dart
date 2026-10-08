import 'package:connection_engine/connection_engine.dart';
import 'package:printer_protocols/printer_protocols.dart';
import 'package:printer_protocols/testing.dart';
import 'package:test/test.dart';

const _scanner = '''
<scan:ScannerCapabilities xmlns:scan="http://schemas.hp.com/imaging/escl/2011/05/03" xmlns:pwg="http://www.pwg.org/schemas/2010/12/sm">
  <pwg:MakeAndModel>Canon imageRUNNER 2630</pwg:MakeAndModel>
  <pwg:SerialNumber>ESCL-SN</pwg:SerialNumber>
  <scan:UUID>escl-uuid</scan:UUID>
  <scan:Platen><scan:PlatenInputCaps>
    <scan:MaxWidth>2550</scan:MaxWidth><scan:MaxHeight>3508</scan:MaxHeight>
    <scan:ColorMode>RGB24</scan:ColorMode>
    <pwg:DocumentFormat>application/pdf</pwg:DocumentFormat>
    <scan:XResolution>300</scan:XResolution>
  </scan:PlatenInputCaps></scan:Platen>
</scan:ScannerCapabilities>''';

const _scannerIdle = '''
<scan:ScannerStatus xmlns:scan="http://schemas.hp.com/imaging/escl/2011/05/03" xmlns:pwg="http://www.pwg.org/schemas/2010/12/sm">
  <pwg:State>Idle</pwg:State>
</scan:ScannerStatus>''';

IppMessage _printerAnswer({bool withDeviceId = true}) {
  return ippResponse(
    groups: [
      IppGroup(IppGroupTag.printer, [
        IppAttribute.single('printer-name', IppValueTag.name, 'Office'),
        IppAttribute.single(
          'printer-make-and-model',
          IppValueTag.text,
          'Xerox VersaLink C7130',
        ),
        if (withDeviceId)
          IppAttribute.single(
            'printer-device-id',
            IppValueTag.text,
            'MFG:Xerox;MDL:VersaLink C7130;SN:IPP-SN;',
          ),
        IppAttribute.single(
          'printer-uuid',
          IppValueTag.uri,
          'urn:uuid:ipp-uuid',
        ),
        IppAttribute.single('printer-state', IppValueTag.enumeration, 3),
        IppAttribute.single('color-supported', IppValueTag.boolean, true),
      ]),
    ],
  );
}

void main() {
  late FakePrinterHttp http;
  late DeviceProbe probe;

  /// Answers by address: a map from `scheme://host:port/path` prefix to
  /// what is there. Anything else is unreachable.
  void network(Map<String, FakeAnswer Function(SentRequest)> devices) {
    http.device = (request) {
      for (final MapEntry(key: prefix, value: answer) in devices.entries) {
        if (request.uri.toString().startsWith(prefix)) return answer(request);
      }
      throw PrinterUnreachable(request.uri, 'nothing there');
    };
  }

  FakeAnswer escl(SentRequest request) {
    return FakeAnswer.text(
      200,
      request.uri.path.endsWith('ScannerStatus') ? _scannerIdle : _scanner,
    );
  }

  setUp(() {
    http = FakePrinterHttp(
      (request) => throw PrinterUnreachable(request.uri, 'x'),
    );
    probe = DeviceProbe(http: http);
  });

  group('probe', () {
    test('describes a device that prints and scans', () async {
      network({
        'http://192.168.1.40:631/ipp/print': (_) =>
            FakeAnswer.ipp(_printerAnswer()),
        'http://192.168.1.40/eSCL': escl,
      });

      final device = await probe.probe(' 192.168.1.40 ');

      expect(device.host, '192.168.1.40');
      expect(device.name, 'Office');
      expect(device.manufacturer, 'Xerox');
      expect(device.model, 'VersaLink C7130');
      expect(device.serialNumber, 'IPP-SN');
      expect(device.uuid, 'ipp-uuid');
      expect(device.print!.color, isTrue);
      expect(device.scan!.sources, ['platen']);
      expect(device.status.state, 'online');
      expect(device.status.scannerState, 'idle');
      expect(device.connections, [
        DeviceConnection(
          type: 'ipp',
          uri: Uri.parse('ipp://192.168.1.40:631/ipp/print'),
        ),
        DeviceConnection(
          type: 'escl',
          uri: Uri.parse('http://192.168.1.40:80/eSCL'),
        ),
      ]);
    });

    test('describes a printer with no scanner', () async {
      network({
        'http://printer.local:631/ipp/print': (_) =>
            FakeAnswer.ipp(_printerAnswer(withDeviceId: false)),
      });

      final device = await probe.probe('printer.local');

      expect(device.scan, isNull);
      expect(device.manufacturer, 'Xerox');
      expect(device.serialNumber, isNull);
      expect(device.connections.single.type, 'ipp');
      expect(device.status.scannerState, 'unknown');
    });

    test('describes a scanner with no printer', () async {
      network({'http://192.168.1.50/eSCL': escl});

      final device = await probe.probe('192.168.1.50');

      expect(device.print, isNull);
      expect(device.manufacturer, 'Canon');
      expect(device.model, 'imageRUNNER 2630');
      expect(device.serialNumber, 'ESCL-SN');
      expect(device.uuid, 'escl-uuid');
      expect(device.connections.single.type, 'escl');
    });

    test(
      'moves to a secure connection when the plain one is refused',
      () async {
        network({
          'http://192.168.1.40:631/': (_) => const FakeAnswer(426),
          'https://192.168.1.40:631/ipp/print': (_) =>
              FakeAnswer.ipp(_printerAnswer()),
          'https://192.168.1.40/eSCL': escl,
        });

        final device = await probe.probe('192.168.1.40');

        expect(device.connections.map((c) => c.type), ['ipps', 'escl']);
        expect(device.connections.every((c) => c.isSecure), isTrue);
      },
    );

    test('looks only where a port was given', () async {
      network({
        'http://localhost:8631/ipp/print': (_) =>
            FakeAnswer.ipp(_printerAnswer()),
        'http://localhost:8631/eSCL': escl,
      });

      final device = await probe.probe('localhost:8631');

      expect(device.connections.map((c) => c.uri.port), [8631, 8631]);
      expect(http.requests.every((r) => r.uri.port == 8631), isTrue);
    });

    test('accepts a full address, with its own path', () async {
      network({
        'https://printer.local:8443/printers/main': (_) =>
            FakeAnswer.ipp(_printerAnswer()),
      });

      final device = await probe.probe(
        'ipps://printer.local:8443/printers/main',
      );

      expect(
        device.connections.single.uri,
        Uri.parse('ipps://printer.local:8443/printers/main'),
      );
    });

    test(
      'tries only secure places for a secure address without a port',
      () async {
        network({});

        await expectLater(
          probe.probe('https://printer.local'),
          throwsA(isA<ProbeFailure>()),
        );
        expect(http.requests.every((r) => r.uri.scheme == 'https'), isTrue);
      },
    );

    test('still describes a scanner whose status cannot be read', () async {
      network({
        'http://192.168.1.50/eSCL/ScannerCapabilities': (_) =>
            FakeAnswer.text(200, _scanner),
        'http://192.168.1.50/eSCL/ScannerStatus': (_) => const FakeAnswer(500),
      });

      final device = await probe.probe('192.168.1.50');

      expect(device.scan, isNotNull);
      expect(device.status.scannerState, 'unknown');
    });

    test('fails as unreachable when nothing answers', () async {
      await expectLater(
        probe.probe('192.168.1.99'),
        throwsA(
          isA<ProbeFailure>()
              .having((f) => f.kind, 'kind', ProbeFailureKind.unreachable)
              .having((f) => f.address, 'address', '192.168.1.99')
              .having((f) => '$f', 'toString', contains('unreachable')),
        ),
      );
    });

    test('fails as not a printer when something else answers', () async {
      network({
        'http://192.168.1.1:631/': (_) => const FakeAnswer(404),
        'http://192.168.1.1/eSCL': (_) => const FakeAnswer(404),
      });

      await expectLater(
        probe.probe('192.168.1.1'),
        throwsA(
          isA<ProbeFailure>().having(
            (f) => f.kind,
            'kind',
            ProbeFailureKind.notAPrinter,
          ),
        ),
      );
    });

    test('fails as not a printer when the printer refuses to answer', () async {
      network({
        'http://192.168.1.40:631/ipp/print': (_) => FakeAnswer.ipp(
          ippResponse(status: IppStatus.serverErrorServiceUnavailable),
        ),
      });

      await expectLater(
        probe.probe('192.168.1.40'),
        throwsA(
          isA<ProbeFailure>().having(
            (f) => f.kind,
            'kind',
            ProbeFailureKind.notAPrinter,
          ),
        ),
      );
    });

    test('rejects what is not an address', () async {
      for (final address in [
        '',
        '   ',
        'two words',
        'http://',
        ':631',
        'a b://c',
        '[::1',
      ]) {
        await expectLater(
          probe.probe(address),
          throwsA(
            isA<ProbeFailure>().having(
              (f) => f.kind,
              'kind',
              ProbeFailureKind.invalidAddress,
            ),
          ),
          reason: '"$address"',
        );
      }
      expect(http.requests, isEmpty);
    });
  });

  group('probe looks where older printers listen', () {
    test('finds IPP at another path when the usual one has none', () async {
      network({
        'http://192.168.1.40:631/ipp/print': (_) => const FakeAnswer(404),
        'http://192.168.1.40:631/ipp/printer': (_) =>
            FakeAnswer.ipp(ippResponse(status: IppStatus.clientErrorNotFound)),
        'http://192.168.1.40:631/ipp': (_) => FakeAnswer.ipp(_printerAnswer()),
      });

      final device = await probe.probe('192.168.1.40');

      expect(
        device.connections.single.uri,
        Uri.parse('ipp://192.168.1.40:631/ipp'),
      );
    });

    test('finds IPP at the root, the last place to look', () async {
      network({
        'http://192.168.1.40:631/ipp': (_) => const FakeAnswer(404),
        'http://192.168.1.40:631/': (_) => FakeAnswer.ipp(_printerAnswer()),
      });

      final device = await probe.probe('192.168.1.40');

      expect(device.connections.single.uri.path, '/');
    });

    test('does not try other paths where nothing listens', () async {
      await expectLater(
        probe.probe('192.168.1.40'),
        throwsA(isA<ProbeFailure>()),
      );

      // One try for each of the three places IPP can be, not one per path.
      expect(
        http.requests.where((r) => r.headers['Content-Type'] != null),
        hasLength(3),
      );
    });

    test('tries only the path that was typed', () async {
      network({'http://192.168.1.40:631/': (_) => const FakeAnswer(404)});

      await expectLater(
        probe.probe('ipp://192.168.1.40:631/printers/office'),
        throwsA(isA<ProbeFailure>()),
      );

      expect(
        http.requests.where((r) => r.method == 'POST').map((r) => r.uri.path),
        ['/printers/office'],
      );
    });
  });

  group('probe and a printer that wants a password', () {
    const credentials = PrinterCredentials(userName: 'ada', password: 'pw');

    FakeAnswer Function(SentRequest) locked(String challenge) {
      return (request) => request.headers['Authorization'] == null
          ? FakeAnswer(401, headers: {'www-authenticate': challenge})
          : FakeAnswer.ipp(_printerAnswer());
    }

    Matcher failsAs(ProbeFailureKind kind) =>
        throwsA(isA<ProbeFailure>().having((e) => e.kind, 'kind', kind));

    test('says so, and does not add it as a scanner alone', () async {
      network({
        'http://192.168.1.40:631/': locked('Digest realm="x", nonce="n"'),
        'http://192.168.1.40/eSCL': escl,
      });

      await expectLater(
        probe.probe('192.168.1.40'),
        failsAs(ProbeFailureKind.needsPassword),
      );
      // Asked once on the port: another path would want the password too.
      expect(
        http.requests.where((r) => r.uri.scheme == 'http' && r.uri.port == 631),
        hasLength(1),
      );
    });

    test('describes it once the password is given', () async {
      network({
        'http://192.168.1.40:631/': locked('Digest realm="x", nonce="n"'),
      });

      final device = await probe.probe(
        '192.168.1.40',
        credentials: credentials,
      );

      expect(device.model, 'VersaLink C7130');
      expect(http.requests.last.headers['Authorization'], contains('Digest'));
    });

    test('says when the password is wrong', () async {
      network({
        'http://192.168.1.40:631/': (_) => const FakeAnswer(
          401,
          headers: {'www-authenticate': 'Digest realm="x", nonce="n"'},
        ),
      });

      await expectLater(
        probe.probe('192.168.1.40', credentials: credentials),
        failsAs(ProbeFailureKind.wrongPassword),
      );
    });

    test('takes a plain password to the secure address only', () async {
      network({
        'http://192.168.1.40:631/': locked('Basic realm="x"'),
        'https://192.168.1.40:631/': locked('Basic realm="x"'),
      });

      final device = await probe.probe(
        '192.168.1.40',
        credentials: credentials,
      );

      expect(device.connections.single.type, 'ipps');
      expect(
        http.requests
            .where((r) => r.headers['Authorization'] != null)
            .map((r) => r.uri.scheme)
            .toSet(),
        {'https'},
      );
    });

    test(
      'says so when there is no secure address for a plain password',
      () async {
        network({'http://192.168.1.40:631/': locked('Basic realm="x"')});

        await expectLater(
          probe.probe('192.168.1.40', credentials: credentials),
          failsAs(ProbeFailureKind.needsPassword),
        );
        expect(
          http.requests.where((r) => r.headers['Authorization'] != null),
          isEmpty,
        );
      },
    );

    test('moves to the secure address when told to upgrade', () async {
      network({
        'http://192.168.1.40:631/': (_) => const FakeAnswer(426),
        'https://192.168.1.40:631/ipp/print': (_) =>
            FakeAnswer.ipp(_printerAnswer()),
      });

      final device = await probe.probe('192.168.1.40');

      expect(device.connections.single.type, 'ipps');
      expect(
        http.requests.where((r) => r.uri.scheme == 'http' && r.uri.port == 631),
        hasLength(1),
      );
    });

    test('gives an announced device its password too', () async {
      network({
        'https://printer.local:631/ipp/print': locked('Basic realm="x"'),
      });

      final device = await probe.probeAnnounced(
        host: 'printer.local',
        ipp: Uri.parse('ipps://printer.local:631/ipp/print'),
        credentials: credentials,
      );

      expect(device.connections.single.type, 'ipps');
    });

    test('reads the status of a printer it has the password for', () async {
      network({
        'http://192.168.1.40:631/': locked('Digest realm="x", nonce="n"'),
      });
      final connections = [
        DeviceConnection(
          type: 'ipp',
          uri: Uri.parse('ipp://192.168.1.40:631/ipp/print'),
        ),
      ];

      expect((await probe.status(connections)).state, 'unreachable');
      expect(
        (await probe.status(connections, credentials: credentials)).state,
        'online',
      );
    });
  });

  group('probeAnnounced', () {
    test('goes straight to where the device said it is', () async {
      network({
        'http://192.168.1.40:8631/printers/main': (_) =>
            FakeAnswer.ipp(_printerAnswer()),
        'http://192.168.1.40:8080/eSCL': escl,
      });

      final device = await probe.probeAnnounced(
        host: '192.168.1.40',
        ipp: Uri.parse('ipp://192.168.1.40:8631/printers/main'),
        escl: Uri.parse('http://192.168.1.40:8080/eSCL'),
      );

      expect(device.host, '192.168.1.40');
      expect(device.connections.map((c) => c.uri.port), [8631, 8080]);
      expect(http.requests.map((r) => r.uri.port).toSet(), {8631, 8080});
    });

    test('looks in the usual places for what was not announced', () async {
      network({
        'http://192.168.1.40:631/ipp/print': (_) =>
            FakeAnswer.ipp(_printerAnswer()),
        'http://192.168.1.40/eSCL': escl,
      });

      final device = await probe.probeAnnounced(
        host: '192.168.1.40',
        ipp: Uri.parse('ipp://192.168.1.40:631/ipp/print'),
      );

      expect(device.scan, isNotNull);
    });

    test('fails when the announced device no longer answers', () async {
      await expectLater(
        probe.probeAnnounced(
          host: '192.168.1.40',
          ipp: Uri.parse('ipp://192.168.1.40:631/ipp/print'),
          escl: Uri.parse('http://192.168.1.40/eSCL'),
        ),
        throwsA(
          isA<ProbeFailure>().having(
            (f) => f.kind,
            'kind',
            ProbeFailureKind.unreachable,
          ),
        ),
      );
    });
  });

  group('status', () {
    final connections = [
      DeviceConnection(
        type: 'ipp',
        uri: Uri.parse('ipp://192.168.1.40:631/ipp/print'),
      ),
      DeviceConnection(
        type: 'escl',
        uri: Uri.parse('http://192.168.1.40:80/eSCL'),
      ),
    ];

    test('reads the printer and the scanner', () async {
      network({
        'http://192.168.1.40:631/ipp/print': (_) =>
            FakeAnswer.ipp(_printerAnswer()),
        'http://192.168.1.40/eSCL': escl,
      });

      final status = await probe.status(connections);

      expect(status.state, 'online');
      expect(status.scannerState, 'idle');
      final asked = decodeIpp(
        http.requests.firstWhere((request) => request.method == 'POST').body,
      ).message.group(IppGroupTag.operation)!['requested-attributes']!.strings;
      expect(asked, contains('marker-levels'));
      expect(asked, isNot(contains('media-supported')));
    });

    test('is unreachable when nothing answers', () async {
      expect(await probe.status(connections), DeviceStatus.unreachable);
    });

    test('is offline when the printer answers that it cannot serve', () async {
      network({
        'http://192.168.1.40:631/ipp/print': (_) => FakeAnswer.ipp(
          ippResponse(status: IppStatus.serverErrorServiceUnavailable),
        ),
      });

      final status = await probe.status(connections);

      expect(status.state, 'offline');
      expect(status.acceptingJobs, isFalse);
    });

    test('uses what answers when part of the device does not', () async {
      network({
        'http://192.168.1.40:631/ipp/print': (_) => const FakeAnswer(404),
        'http://192.168.1.40/eSCL': (_) => const FakeAnswer(404),
      });
      expect(await probe.status(connections), DeviceStatus.unreachable);

      network({'http://192.168.1.40/eSCL': escl});
      final scannerOnly = await probe.status(connections);
      expect(scannerOnly.state, 'online');
      expect(scannerOnly.scannerState, 'idle');
    });

    test(
      'tries every connection, and lets the first of a kind speak',
      () async {
        final spare = DeviceConnection(
          type: 'ipps',
          uri: Uri.parse('ipps://192.168.1.40:443/ipp/print'),
        );
        network({
          'http://192.168.1.40:631/ipp/print': (_) =>
              FakeAnswer.ipp(_printerAnswer()),
          'https://192.168.1.40/ipp/print': (_) => FakeAnswer.ipp(
            ippResponse(status: IppStatus.serverErrorServiceUnavailable),
          ),
        });

        final status = await probe.status([connections.first, spare]);

        expect(status.state, 'online');
        expect(http.requests, hasLength(2));
      },
    );
  });

  group('check', () {
    final ipp = DeviceConnection(
      type: 'ipp',
      uri: Uri.parse('ipp://192.168.1.40:631/ipp/print'),
    );
    final scan = DeviceConnection(
      type: 'escl',
      uri: Uri.parse('http://192.168.1.40:80/eSCL'),
    );

    Future<String> healthOf(
      DeviceConnection connection,
      FakeAnswer Function(SentRequest)? device,
    ) async {
      network({'http': ?device});
      final result = await probe.check([connection]);
      return result.checks.single.health;
    }

    test('says how each connection did, in the order given', () async {
      network({
        'http://192.168.1.40:631/ipp/print': (_) =>
            FakeAnswer.ipp(_printerAnswer()),
      });

      final result = await probe.check([ipp, scan]);

      expect(result.status.state, 'online');
      expect(result.checks.map((check) => check.connection), [ipp, scan]);
      final printing = result.checks.first;
      expect(printing.health, 'connected');
      expect(printing.latencyMs, isNonNegative);
      expect(printing.error, isNull);
      expect(printing.answered, isTrue);
      final scanning = result.checks.last;
      expect(scanning.health, 'unavailable');
      expect(scanning.latencyMs, isNull);
      expect(scanning.error, 'nothing there');
      expect(scanning.answered, isFalse);
      expect(printing, isNot(scanning));
    });

    test('tells apart the ways a printing connection can fail', () async {
      expect(await healthOf(ipp, null), 'unavailable');
      expect(
        await healthOf(
          ipp,
          (_) => FakeAnswer.ipp(
            ippResponse(status: IppStatus.serverErrorServiceUnavailable),
          ),
        ),
        'degraded',
      );
      expect(
        await healthOf(
          ipp,
          (_) => const FakeAnswer(
            401,
            headers: {'www-authenticate': 'Digest realm="x", nonce="n"'},
          ),
        ),
        'auth_required',
      );
      expect(
        await healthOf(ipp, (_) => const FakeAnswer(404)),
        'config_required',
      );
    });

    test('tells apart the ways a scanning connection can fail', () async {
      expect(await healthOf(scan, escl), 'connected');
      expect(
        await healthOf(scan, (_) => const FakeAnswer(404)),
        'config_required',
      );
      expect(await healthOf(scan, (_) => const FakeAnswer(503)), 'degraded');
      expect(await healthOf(scan, (_) => const FakeAnswer(500)), 'unavailable');
    });

    test('a device with nothing to try is unreachable', () async {
      final result = await probe.check(const []);

      expect(result.status, DeviceStatus.unreachable);
      expect(result.checks, isEmpty);
    });
  });
}
