// Runs the protocol clients against `backend/simulator`, a fake Xerox
// VersaLink C7130. Start it with `make simulator`, then:
//
//   dart test --tags simulator
//
// These are skipped when the simulator is not running, so the ordinary test
// run never depends on it.
@Tags(['simulator'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:printer_protocols/printer_protocols.dart';
import 'package:test/test.dart';

final Uri _base = Uri.parse(
  Platform.environment['SIMULATOR_URL'] ?? 'http://localhost:8631',
);

Future<bool> _running() async {
  try {
    final socket = await Socket.connect(
      _base.host,
      _base.port,
      timeout: const Duration(seconds: 1),
    );
    socket.destroy();
    return true;
  } on Object {
    return false;
  }
}

void main() {
  // Asked once, by whichever test runs first. Declaring tests must not wait
  // on anything, so each test checks and skips itself.
  final running = _running();

  /// A test that needs the simulator, skipped when it is not running.
  void simulatorTest(String description, Future<void> Function() body) {
    test(description, () async {
      if (!await running) {
        markTestSkipped('The simulator is not running (make simulator).');
        return;
      }
      await body();
    });
  }

  final http = IoPrinterHttp();
  final ipp = IppClient(
    printerUri: _base.replace(path: '/ipp/print'),
    http: http,
  );
  final escl = EsclClient(
    baseUri: _base.replace(path: '/eSCL'),
    http: http,
  );
  final control = HttpClient();

  /// Changes the simulated device: faults, toner, timings.
  Future<void> simulate(Map<String, Object?> state) async {
    final request = await control.openUrl(
      'PATCH',
      _base.replace(path: '/sim/state'),
    );
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(state));
    await (await request.close()).drain<void>();
  }

  Future<void> reset() async {
    final request = await control.postUrl(_base.replace(path: '/sim/reset'));
    await (await request.close()).drain<void>();
  }

  setUp(() async {
    if (await running) await reset();
  });
  tearDownAll(() async {
    if (await running) await reset();
    http.close();
    control.close(force: true);
  });

  group('IPP', () {
    simulatorTest('describes the printer', () async {
      final printer = await ipp.getPrinterAttributes();

      expect(printer.makeAndModel, contains('VersaLink C7130'));
      expect(printer.state, IppPrinterState.idle);
      expect(printer.isAcceptingJobs, isTrue);
      expect(printer.colorSupported, isTrue);
      expect(printer.documentFormats, contains('application/pdf'));
      expect(printer.sides, contains('two-sided-long-edge'));
      expect(printer.media, contains('iso_a4_210x297mm'));
      expect(printer.maxCopies, 999);
      expect(printer.resolutionsDpi, [600, 1200]);
      expect(printer.qualities, ['draft', 'normal', 'high']);
      expect(
        printer.markers.map((m) => m.color),
        containsAll(['cyan', 'black']),
      );
      expect(printer.supportsAirPrint, isTrue);
      expect(printer.uuid, isNotEmpty);
    });

    simulatorTest('answers with only the attributes asked for', () async {
      final printer = await ipp.getPrinterAttributes(
        requested: ['printer-state', 'marker-levels'],
      );

      expect(printer.group.attributes.map((a) => a.name), [
        'printer-state',
        'marker-levels',
      ]);
    });

    simulatorTest('prints a document and follows it to completion', () async {
      await simulate({'job_duration_seconds': 0.6});
      final document = utf8.encode('%PDF-1.7 simulated');

      const options = IppJobOptions(jobName: 'Smoke', copies: 2);
      await ipp.validateJob(options);
      final job = await ipp.printJob(
        document: Stream.value(document),
        length: document.length,
        options: options,
      );
      expect(job.id, greaterThan(0));
      expect((await ipp.getJobs()).map((j) => j.id), contains(job.id));

      var current = job;
      for (var i = 0; i < 40 && !current.state.isFinished; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        current = await ipp.getJobAttributes(job.id);
      }
      expect(current.state, IppJobState.completed);
    });

    simulatorTest('cancels a job', () async {
      await simulate({'job_duration_seconds': 30});
      final job = await ipp.printJob(
        document: Stream.value(utf8.encode('%PDF')),
        options: const IppJobOptions(),
      );

      await ipp.cancelJob(job.id);

      expect((await ipp.getJobAttributes(job.id)).state, IppJobState.canceled);
    });

    simulatorTest('refuses a document format it cannot print', () async {
      await expectLater(
        ipp.validateJob(const IppJobOptions(documentFormat: 'text/x-unknown')),
        throwsA(
          isA<IppException>().having(
            (e) => e.statusCode,
            'statusCode',
            IppStatus.clientErrorDocumentFormatNotSupported,
          ),
        ),
      );
    });

    simulatorTest('reports a paper jam', () async {
      await simulate({
        'faults': {'paper_jam': true},
      });

      final printer = await ipp.getPrinterAttributes();

      expect(printer.stateReasons, contains('media-jam-error'));
    });

    simulatorTest('reports low toner', () async {
      await simulate({
        'toner': {'cyan': 4},
      });

      final cyan = (await ipp.getPrinterAttributes()).markers.firstWhere(
        (marker) => marker.color == 'cyan',
      );

      expect(cyan.levelPercent, 4);
    });

    simulatorTest('answers unavailable while offline', () async {
      await simulate({
        'faults': {'offline': true},
      });

      await expectLater(
        ipp.getPrinterAttributes(),
        throwsA(
          isA<IppException>().having(
            (e) => e.statusCode,
            'statusCode',
            IppStatus.serverErrorServiceUnavailable,
          ),
        ),
      );
    });
  });

  group('eSCL', () {
    simulatorTest('describes the scanner', () async {
      final capabilities = await escl.capabilities();

      expect(capabilities.makeAndModel, contains('VersaLink C7130'));
      expect(capabilities.platen!.resolutionsDpi, [150, 200, 300, 400, 600]);
      expect(capabilities.platen!.colorModes, contains('RGB24'));
      expect(capabilities.platen!.documentFormats, contains('application/pdf'));
      expect(capabilities.feeder, isNotNull);
      expect(capabilities.feederDuplex, isTrue);
      expect((await escl.status()).state, EsclScannerState.idle);
    });

    simulatorTest('scans one page from the glass', () async {
      final job = await escl.startScan(const EsclScanSettings());

      final page = await escl.nextDocument(job);
      final bytes = await page!.bytes.expand((chunk) => chunk).toList();

      expect(page.contentType, contains('application/pdf'));
      expect(utf8.decode(bytes.take(5).toList()), '%PDF-');
      expect(await escl.nextDocument(job), isNull);
    });

    simulatorTest('scans every sheet in the feeder', () async {
      await simulate({'adf_pages': 3});
      final job = await escl.startScan(
        const EsclScanSettings(fromFeeder: true),
      );

      var pages = 0;
      while (true) {
        final page = await escl.nextDocument(job);
        if (page == null) break;
        await page.bytes.drain<void>();
        pages++;
      }

      expect(pages, 3);
    });

    simulatorTest('refuses a feeder scan with nothing in the feeder', () async {
      await simulate({
        'faults': {'adf_empty': true},
      });

      expect((await escl.status()).feederEmpty, isTrue);
      await expectLater(
        escl.startScan(const EsclScanSettings(fromFeeder: true)),
        throwsA(
          isA<EsclException>().having((e) => e.notReady, 'notReady', isTrue),
        ),
      );
    });

    simulatorTest('cancels a scan', () async {
      await simulate({'adf_pages': 5});
      final job = await escl.startScan(
        const EsclScanSettings(fromFeeder: true),
      );

      await escl.cancel(job);

      expect((await escl.status()).state, EsclScannerState.idle);
    });

    simulatorTest('says so when the firmware has eSCL switched off', () async {
      await simulate({
        'faults': {'escl_disabled': true},
      });

      await expectLater(
        escl.capabilities(),
        throwsA(
          isA<EsclException>().having(
            (e) => e.notSupported,
            'notSupported',
            isTrue,
          ),
        ),
      );
    });
  });
}
