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
import 'dart:typed_data';

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

  /// What the simulated device holds: its jobs, as it received them.
  Future<Map<String, dynamic>> state() async {
    final request = await control.getUrl(_base.replace(path: '/sim/state'));
    final body = await utf8.decodeStream(await request.close());
    return jsonDecode(body) as Map<String, dynamic>;
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
        length: 4,
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

    simulatorTest(
      'accepts a tray and a paper type, asked for properly',
      () async {
        await ipp.validateJob(
          const IppJobOptions(
            media: 'iso_a4_210x297mm',
            mediaSource: 'tray-2',
            mediaType: 'stationery',
            sides: 'two-sided-long-edge',
          ),
        );
      },
    );

    simulatorTest(
      'draws the pages for a printer that does not read PDF',
      () async {
        await simulate({
          'document_formats': ['image/pwg-raster', 'image/urf', 'image/jpeg'],
          'job_duration_seconds': 0,
        });
        final printer = await ipp.getPrinterAttributes();

        final target =
            choosePrintFormat(printer, sourceType: 'application/pdf')!
                as RasterTarget;
        expect(target.format, RasterFormat.pwg);
        expect(target.color, RasterColor.srgb8);
        expect(target.resolutionDpi, 300);
        expect(target.sheetBack, SheetBack.rotated);

        // Three A5 pages, each with a band of colour so they are not blank.
        final document = target.document(
          media: PwgMedia.parse('iso_a5_148x210mm')!,
          pageCount: 3,
          sides: RasterSides.twoSidedLongEdge,
        );
        final encoder = RasterEncoder(document);
        final bytes = BytesBuilder()..add(encoder.start());
        for (var page = 0; page < 3; page++) {
          final pixels = Uint8List(document.bytesPerPage)
            ..fillRange(0, document.bytesPerPage, 255)
            ..fillRange(0, document.bytesPerLine * 40 * (page + 1), 60 * page);
          bytes.add(encoder.page(pixels, index: page));
        }
        final file = bytes.takeBytes();

        final job = await ipp.printJob(
          document: Stream.value(file),
          length: file.length,
          options: IppJobOptions(
            documentFormat: target.mimeType,
            sides: 'two-sided-long-edge',
          ),
        );

        // The simulator reads the document back the way a printer would, and
        // counts three pages in it.
        final received = ((await state())['print_jobs'] as List).last as Map;
        expect(received['id'], job.id);
        expect(received['document_format'], 'image/pwg-raster');
        expect(received['pages'], 3);
        expect(received['size_bytes'], file.length);
      },
    );

    simulatorTest(
      'draws Apple Raster for a printer with AirPrint alone',
      () async {
        await simulate({
          'document_formats': ['image/urf'],
        });
        final printer = await ipp.getPrinterAttributes();
        final target =
            choosePrintFormat(
                  printer,
                  sourceType: 'application/pdf',
                  color: false,
                )!
                as RasterTarget;
        expect(target.format, RasterFormat.urf);
        expect(target.color, RasterColor.sgray8);

        final document = target.document(
          media: PwgMedia.parse('na_letter_8.5x11in')!,
          pageCount: 2,
        );
        final encoder = RasterEncoder(document);
        final file = Uint8List.fromList([
          ...encoder.start(),
          for (var page = 0; page < 2; page++)
            ...encoder.page(
              Uint8List(document.bytesPerPage)
                ..fillRange(0, document.bytesPerLine * 100, 200),
              index: page,
            ),
        ]);

        await ipp.printJob(
          document: Stream.value(file),
          length: file.length,
          options: IppJobOptions(documentFormat: target.mimeType),
        );

        final received = ((await state())['print_jobs'] as List).last as Map;
        expect(received['pages'], 2);
      },
    );

    simulatorTest('falls back to IPP 1.1 for an old printer', () async {
      await simulate({
        'faults': {'ipp_1_1_only': true},
      });
      final old = IppClient(
        printerUri: _base.replace(path: '/ipp/print'),
        http: http,
      );

      expect(
        (await old.getPrinterAttributes()).makeAndModel,
        contains('VersaLink'),
      );
      final job = await old.printJob(
        document: Stream.value(utf8.encode('%PDF')),
        length: 4,
        options: const IppJobOptions(),
      );
      expect(job.id, greaterThan(0));
    });

    simulatorTest('signs in to a printer that asks who is printing', () async {
      await simulate({
        'auth': 'digest',
        'auth_user': 'ada',
        'auth_password': 'correct horse',
      });

      await expectLater(
        ipp.getPrinterAttributes(),
        throwsA(
          isA<IppNotAvailable>().having(
            (e) => e.needsAuthentication,
            'needsAuthentication',
            isTrue,
          ),
        ),
      );

      IppClient as(String password) => IppClient(
        printerUri: _base.replace(path: '/ipp/print'),
        http: http,
        credentials: PrinterCredentials(userName: 'ada', password: password),
      );
      await expectLater(
        as('wrong').getPrinterAttributes(),
        throwsA(
          isA<IppNotAvailable>().having(
            (e) => e.credentialsRefused,
            'credentialsRefused',
            isTrue,
          ),
        ),
      );

      final signedIn = as('correct horse');
      expect(
        (await signedIn.getPrinterAttributes()).requiresAuthentication,
        isTrue,
      );
      final job = await signedIn.printJob(
        document: Stream.value(utf8.encode('%PDF')),
        length: 4,
        options: const IppJobOptions(jobName: 'Signed'),
      );
      final received = ((await state())['print_jobs'] as List).last as Map;
      expect(received['id'], job.id);
      expect(received['user'], 'ada');
    });

    simulatorTest('keeps a Basic password off an open connection', () async {
      await simulate({'auth': 'basic'});

      await expectLater(
        IppClient(
          printerUri: _base.replace(path: '/ipp/print'),
          http: http,
          credentials: const PrinterCredentials(
            userName: 'printer',
            password: 'secret',
          ),
        ).getPrinterAttributes(),
        throwsA(
          isA<IppNotAvailable>().having((e) => e.needsTls, 'needsTls', isTrue),
        ),
      );
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
      await escl.cancel(job);
    });

    simulatorTest('fits the settings to what the scanner offers', () async {
      final feeder = (await escl.capabilities()).feeder!;

      final settings = feeder.settings(
        fromFeeder: true,
        color: false,
        resolutionDpi: 250,
        documentFormat: 'image/tiff',
      );
      expect(settings.colorMode, 'Grayscale8');
      expect(settings.resolutionDpi, isIn([200, 300]));
      expect(settings.documentFormat, 'image/jpeg');

      final job = await escl.startScan(settings);
      final page = await escl.nextDocument(job);
      expect(page!.contentType, contains('image/jpeg'));
      await page.bytes.drain<void>();
      await escl.cancel(job);
    });

    simulatorTest('waits for pages that take a while to arrive', () async {
      await simulate({'adf_pages': 2, 'scan_busy_responses': 2});
      final patient = EsclClient(
        baseUri: _base.replace(path: '/eSCL'),
        http: http,
        retryPause: const Duration(milliseconds: 20),
      );
      final job = await patient.startScan(
        const EsclScanSettings(fromFeeder: true),
      );

      var pages = 0;
      while (true) {
        final page = await patient.nextDocument(job);
        if (page == null) break;
        await page.bytes.drain<void>();
        pages++;
      }

      expect(pages, 2);
      expect(job.pagesReceived, 2);
    });

    simulatorTest('finds the job when the scanner misnames itself', () async {
      for (final style in ['path', 'wrong_host']) {
        await simulate({'scan_location': style});
        final job = await escl.startScan(const EsclScanSettings());

        expect(job.uri.host, _base.host, reason: style);
        expect(job.uri.port, _base.port, reason: style);
        final page = await escl.nextDocument(job);
        await page!.bytes.drain<void>();
        await escl.cancel(job);
      }
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
