import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:connection_engine/connection_engine.dart';
import 'package:printer_protocols/printer_protocols.dart';
import 'package:printer_protocols/testing.dart';
import 'package:test/test.dart';

const _pdf = 'application/pdf';

/// A printer that answers IPP on any connection of `192.168.1.40`, and
/// keeps what it was sent.
class _Printer {
  List<String> formats = [_pdf, 'image/pwg-raster'];
  List<String> sides = ['one-sided', 'two-sided-long-edge'];
  List<String> rasterTypes = ['sgray_8', 'srgb_8'];

  /// What the printer reads inside media-col. Empty when it does not say.
  List<String> mediaCol = [];
  int? validateStatus;
  int? printStatus;

  /// The states the job passes through, one per time it is asked about.
  List<int> jobStates = [5, 9];
  List<String> stoppedReasons = ['media-empty-error'];

  /// Called as the document arrives. Throw to drop the connection.
  void Function(SentRequest request)? onDocument;

  /// False makes the printer forget the job at once.
  bool remembersJobs = true;

  final List<IppDecoded> jobs = [];
  final List<int> operations = [];
  final List<int> cancelled = [];
  int _asked = 0;

  IppGroup _job(int state, {String? name}) => IppGroup(IppGroupTag.job, [
    IppAttribute.single('job-id', IppValueTag.integer, 7),
    IppAttribute.single('job-state', IppValueTag.enumeration, state),
    if (name != null) IppAttribute.single('job-name', IppValueTag.name, name),
    if (state == 6 || state == 8)
      IppAttribute.all(
        'job-state-reasons',
        IppValueTag.keyword,
        stoppedReasons,
      ),
  ]);

  FakeAnswer answer(SentRequest request) {
    final decoded = decodeIpp(request.body);
    final operation = decoded.message.code;
    operations.add(operation);
    FakeAnswer ipp({
      int status = IppStatus.ok,
      List<IppGroup> groups = const [],
    }) {
      return FakeAnswer.ipp(ippResponse(status: status, groups: groups));
    }

    switch (operation) {
      case IppOperation.getPrinterAttributes:
        return ipp(
          groups: [
            IppGroup(IppGroupTag.printer, [
              IppAttribute.all(
                'document-format-supported',
                IppValueTag.mimeMediaType,
                formats,
              ),
              IppAttribute.single('color-supported', IppValueTag.boolean, true),
              IppAttribute.all('sides-supported', IppValueTag.keyword, sides),
              IppAttribute.all('media-supported', IppValueTag.keyword, const [
                'iso_a4_210x297mm',
                'iso_a5_148x210mm',
              ]),
              IppAttribute.single(
                'media-default',
                IppValueTag.keyword,
                'iso_a5_148x210mm',
              ),
              IppAttribute.all(
                'media-source-supported',
                IppValueTag.keyword,
                const ['auto', 'tray-1'],
              ),
              if (mediaCol.isNotEmpty)
                IppAttribute.all(
                  'media-col-supported',
                  IppValueTag.keyword,
                  mediaCol,
                ),
              IppAttribute.all(
                'print-color-mode-supported',
                IppValueTag.keyword,
                const ['auto', 'color', 'monochrome'],
              ),
              IppAttribute.all(
                'print-quality-supported',
                IppValueTag.enumeration,
                const [4, 5],
              ),
              IppAttribute.single(
                'copies-supported',
                IppValueTag.rangeOfInteger,
                const IppRange(1, 99),
              ),
              IppAttribute.all(
                'multiple-document-handling-supported',
                IppValueTag.keyword,
                const ['separate-documents-collated-copies'],
              ),
              IppAttribute.all(
                'pwg-raster-document-type-supported',
                IppValueTag.keyword,
                rasterTypes,
              ),
              IppAttribute.single(
                'pwg-raster-document-resolution-supported',
                IppValueTag.resolution,
                const IppResolution(300, 300),
              ),
            ]),
          ],
        );
      case IppOperation.validateJob:
        return ipp(status: validateStatus ?? IppStatus.ok);
      case IppOperation.printJob:
        onDocument?.call(request);
        if (printStatus != null) return ipp(status: printStatus!);
        jobs.add(decoded);
        return ipp(groups: [_job(3)]);
      case IppOperation.getJobAttributes:
        if (!remembersJobs) return ipp(status: IppStatus.clientErrorNotFound);
        final state =
            jobStates[_asked < jobStates.length
                ? _asked
                : jobStates.length - 1];
        _asked++;
        return ipp(groups: [_job(state)]);
      case IppOperation.getJobs:
        return ipp(
          groups: [
            for (final job in jobs)
              _job(
                5,
                name:
                    job.message
                            .group(IppGroupTag.operation)!['job-name']!
                            .first!
                        as String,
              ),
          ],
        );
      default:
        cancelled.add(operation);
        jobStates = [7];
        return ipp();
    }
  }
}

void main() {
  late _Printer printer;
  late FakePrinterHttp http;
  late Directory spool;
  late List<Duration> pauses;

  final ipp = DeviceConnection(
    type: 'ipp',
    uri: Uri.parse('ipp://192.168.1.40:631/ipp/print'),
  );
  final ipps = DeviceConnection(
    type: 'ipps',
    uri: Uri.parse('ipps://192.168.1.40:443/ipp/print'),
  );
  final scan = DeviceConnection(
    type: 'escl',
    uri: Uri.parse('http://192.168.1.40:80/eSCL'),
  );
  final bytes = utf8.encode('%PDF-1.7 a document');

  PrintDocument document({
    String mimeType = _pdf,
    int? pageCount = 2,
    bool canDraw = true,
  }) {
    return PrintDocument(
      name: 'Report.pdf',
      mimeType: mimeType,
      length: bytes.length,
      open: () => Stream.value(bytes),
      pageCount: pageCount,
      rasterise: canDraw
          ? (page) async* {
              for (var i = 0; i < (pageCount ?? 0); i++) {
                yield Uint8List(page.bytesPerPage)
                  ..fillRange(0, page.bytesPerPage, 255);
              }
            }
          : null,
    );
  }

  PrintRunner runner({Duration watchFor = const Duration(minutes: 10)}) {
    return PrintRunner(
      http: http,
      spoolDirectory: spool,
      watchFor: watchFor,
      pause: (duration) async => pauses.add(duration),
    );
  }

  Future<List<PrintProgress>> run({
    List<DeviceConnection>? connections,
    PrintDocument? what,
    PrintRequest request = const PrintRequest(),
    PrintRunner? using,
  }) {
    return (using ?? runner())
        .start(
          connections: connections ?? [ipp],
          document: what ?? document(),
          request: request,
          reference: 'ab12cd34',
        )
        .progress
        .toList();
  }

  IppGroup jobAttributes([int index = 0]) =>
      printer.jobs[index].message.group(IppGroupTag.job) ??
      IppGroup(IppGroupTag.job);

  String operationAttribute(String name, [int index = 0]) =>
      printer.jobs[index].message.group(IppGroupTag.operation)![name]!.first!
          as String;

  setUp(() {
    printer = _Printer();
    pauses = [];
    spool = Directory.systemTemp.createTempSync('print-runner-test');
    http = FakePrinterHttp((request) {
      if (request.uri.scheme == 'https') {
        throw PrinterUnreachable(request.uri, 'no TLS here');
      }
      return printer.answer(request);
    });
  });
  tearDown(() => spool.deleteSync(recursive: true));

  group('a printer that reads the file', () {
    test('is sent it as it is, and followed until it is done', () async {
      final steps = await run();

      // One side is said outright: the printer's own habit may be two.
      expect(jobAttributes().attributes.single.name, 'sides');
      expect(jobAttributes()['sides']!.first, 'one-sided');

      expect(steps.map((step) => step.stage), [
        PrintStage.connecting,
        PrintStage.preparing,
        PrintStage.sending,
        PrintStage.printing,
        PrintStage.completed,
      ]);
      expect(steps.last.isFinal, isTrue);
      expect(steps.last.printerJobId, 7);
      expect(steps.last.connection, ipp);
      expect(steps.last.fellBack, isFalse);
      expect(steps.first.isFinal, isFalse);
      expect(printer.jobs.single.data, bytes);
      expect(operationAttribute('document-format'), _pdf);
      // Named so it can be found on the printer again.
      expect(operationAttribute('job-name'), 'Report.pdf [ab12cd34]');
      expect(pauses, everyElement(const Duration(seconds: 1)));
    });

    test('is asked first, and sent nothing it would refuse', () async {
      printer.validateStatus = IppStatus.clientErrorNotPossible;

      final steps = await run(connections: [ipp, ipp]);

      expect(steps.last.stage, PrintStage.failed);
      expect(steps.last.errorCode, 'ipp.client-error-not-possible');
      expect(printer.jobs, isEmpty);
      // Refused for what was asked: asking again elsewhere is no use.
      expect(
        printer.operations.where((o) => o == IppOperation.validateJob),
        hasLength(1),
      );
    });

    test('gets only the choices it offers', () async {
      await run(
        request: const PrintRequest(
          copies: 3,
          sides: 'two_sided_long_edge',
          color: 'monochrome',
          media: 'iso_a4_210x297mm',
          tray: 'tray-1',
          quality: 'high',
          pageRanges: '1-2, 4',
          orientation: 'landscape',
        ),
      );

      final job = jobAttributes();
      expect(job['copies']!.first, 3);
      expect(job['sides']!.first, 'two-sided-long-edge');
      expect(job['print-color-mode']!.first, 'monochrome');
      expect(job['print-quality']!.first, 5);
      expect(job['orientation-requested']!.first, 4);
      expect(job['page-ranges']!.values.map((v) => v.value), const [
        IppRange(1, 2),
        IppRange(4, 4),
      ]);
      expect(
        job['multiple-document-handling']!.first,
        'separate-documents-collated-copies',
      );
      // A tray is asked for with the paper, inside media-col.
      final mediaCol = job['media-col']!.first! as Map<String, IppAttribute>;
      expect(mediaCol['media-source']!.first, 'tray-1');
    });

    test('is not asked for what it does not offer', () async {
      await run(
        request: const PrintRequest(
          copies: 500,
          sides: 'two_sided_short_edge',
          media: 'na_legal_8.5x14in',
          tray: 'tray-9',
          mediaType: 'cardstock',
          quality: 'draft',
          pageRanges: '5-2',
        ),
      );

      // Every choice fell away, and the printer uses its own.
      expect(jobAttributes().attributes, isEmpty);
    });

    test('is not asked for a tray when it cannot be told one', () async {
      printer.mediaCol = ['media-size'];
      await run(request: const PrintRequest(tray: 'tray-1'));
      expect(jobAttributes()['media-col'], isNull);

      printer
        ..jobs.clear()
        ..mediaCol = ['media-size', 'media-source'];
      await run(request: const PrintRequest(tray: 'tray-1'));
      expect(jobAttributes()['media-col'], isNotNull);
    });

    test('ignores page ranges that are not ranges', () async {
      for (final ranges in ['', 'all', '0-3', '2-x']) {
        printer.jobs.clear();
        await run(request: PrintRequest(pageRanges: ranges));
        expect(jobAttributes()['page-ranges'], isNull, reason: ranges);
      }
    });
  });

  group('a printer that does not read the file', () {
    setUp(() => printer.formats = ['image/pwg-raster', 'image/jpeg']);

    test('is sent pictures of the pages, with their size known', () async {
      final steps = await run(
        request: const PrintRequest(
          sides: 'two_sided_long_edge',
          quality: 'normal',
        ),
      );

      expect(steps.last.stage, PrintStage.completed);
      expect(operationAttribute('document-format'), 'image/pwg-raster');
      final sent = printer.jobs.single.data;
      expect(ascii.decode(sent.sublist(0, 4)), 'RaS2');
      // Two pages, on the printer's own paper, since none was chosen: A5.
      final header = ByteData.sublistView(sent, 4, 4 + 1796);
      expect(header.getUint32(372), 1748);
      expect(header.getUint32(452), 2, reason: 'TotalPageCount');
      expect(header.getUint32(272), 1, reason: 'Duplex');
      expect(header.getUint32(484), 4, reason: 'PrintQuality');
      // Nothing is left behind on the phone.
      expect(spool.listSync(), isEmpty);
    });

    test('is sent grey when colour is not wanted', () async {
      await run(request: const PrintRequest(color: 'monochrome'));

      final header = ByteData.sublistView(printer.jobs.single.data, 4);
      expect(header.getUint32(400), 18, reason: 'sGray');
    });

    test('draws on A4 when neither the request nor the printer says', () async {
      http.device = (request) {
        final answer = printer.answer(request);
        return answer;
      };
      await run(request: const PrintRequest(media: 'iso_a4_210x297mm'));

      final header = ByteData.sublistView(printer.jobs.single.data, 4);
      expect(header.getUint32(372), 2480);
    });

    test('cannot be printed to when the pages cannot be drawn', () async {
      for (final what in [
        document(canDraw: false),
        document(pageCount: null),
      ]) {
        final steps = await run(what: what, connections: [ipp, ipp]);

        expect(steps.last.stage, PrintStage.failed);
        expect(steps.last.errorCode, 'print.format_not_supported');
        // No other connection changes what the printer reads.
        expect(steps.where((s) => s.stage == PrintStage.connecting), [
          isA<PrintProgress>(),
        ]);
      }
      expect(printer.jobs, isEmpty);
    });

    test('cannot be printed to when it takes nothing the app makes', () async {
      printer.formats = ['application/postscript'];

      final steps = await run();

      expect(steps.last.errorCode, 'print.format_not_supported');
    });

    test('leaves nothing behind when the printer refuses the pages', () async {
      printer.printStatus = IppStatus.clientErrorDocumentFormatNotSupported;

      final steps = await run();

      expect(steps.last.stage, PrintStage.failed);
      expect(spool.listSync(), isEmpty);
    });
  });

  group('falling back to another connection', () {
    test('happens when the first does not answer', () async {
      final steps = await run(connections: [ipps, scan, ipp]);

      expect(steps.map((step) => (step.stage, step.connection?.type)), [
        (PrintStage.connecting, 'ipps'),
        (PrintStage.connecting, 'ipp'),
        (PrintStage.preparing, 'ipp'),
        (PrintStage.sending, 'ipp'),
        (PrintStage.printing, 'ipp'),
        (PrintStage.completed, 'ipp'),
      ]);
      expect(steps.first.fellBack, isFalse);
      expect(steps.last.fellBack, isTrue);
      expect(printer.jobs, hasLength(1));
    });

    test('happens when a connection wants a password or has no IPP', () async {
      for (final (status, code) in [
        (401, 'print.needs_password'),
        (404, 'print.not_available'),
      ]) {
        http.device = (_) => FakeAnswer(status);

        final steps = await run();

        expect(steps.last.stage, PrintStage.failed);
        expect(steps.last.errorCode, code);
      }
    });

    test('happens when the printer is too busy to take the job', () async {
      printer.validateStatus = IppStatus.serverErrorBusy;

      final steps = await run(connections: [ipp, ipp]);

      expect(
        steps.where((step) => step.stage == PrintStage.connecting),
        hasLength(2),
      );
      expect(steps.last.stage, PrintStage.failed);
      expect(steps.last.errorCode, 'ipp.server-error-busy');
    });

    test('says so when there is no way to print at all', () async {
      final steps = await run(connections: [scan]);

      expect(steps.single.stage, PrintStage.failed);
      expect(steps.single.errorCode, 'print.no_connection');
      expect(steps.single.connection, isNull);
    });

    test('says so when nothing answers', () async {
      final steps = await run(connections: [ipps]);

      expect(steps.last.errorCode, 'print.unreachable');
    });
  });

  group('a connection that drops as the document goes', () {
    void dropOnce() {
      var dropped = false;
      printer.onDocument = (request) {
        if (dropped) return;
        dropped = true;
        throw PrinterUnreachable(request.uri, 'connection reset');
      };
    }

    test('moves on when the printer says the job never arrived', () async {
      dropOnce();

      final steps = await run(connections: [ipp, ipp]);

      expect(steps.last.stage, PrintStage.completed);
      expect(steps.last.fellBack, isTrue);
      expect(printer.jobs, hasLength(1));
    });

    test('follows the job when the printer has it after all', () async {
      // The document arrived; only the answer was lost.
      var dropped = false;
      http.device = (request) {
        final answer = printer.answer(request);
        if (printer.operations.last == IppOperation.printJob && !dropped) {
          dropped = true;
          throw PrinterUnreachable(request.uri, 'connection reset');
        }
        return answer;
      };

      final steps = await run(connections: [ipp, ipp]);

      expect(steps.last.stage, PrintStage.completed);
      expect(steps.last.fellBack, isFalse);
      // Printed once, not twice.
      expect(printer.jobs, hasLength(1));
      expect(
        printer.operations.where((o) => o == IppOperation.printJob),
        hasLength(1),
      );
    });

    test('stops and says so when the printer cannot be asked', () async {
      var gone = false;
      http.device = (request) {
        if (gone) throw PrinterUnreachable(request.uri, 'off');
        final answer = printer.answer(request);
        if (printer.operations.last == IppOperation.printJob) {
          gone = true;
          throw PrinterUnreachable(request.uri, 'connection reset');
        }
        return answer;
      };

      final steps = await run(connections: [ipp, ipp]);

      // Sending it again could print it twice: the person decides.
      expect(steps.last.stage, PrintStage.unknown);
      expect(steps.last.errorCode, 'print.outcome_unknown');
      expect(steps.last.isFinal, isTrue);
      expect(
        steps.where((step) => step.stage == PrintStage.connecting),
        hasLength(1),
      );
    });
  });

  group('following a job', () {
    test(
      'says when the printer stops for something, and when it goes on',
      () async {
        printer.jobStates = [6, 6, 5, 9];

        final steps = await run();

        expect(steps.map((step) => step.stage).skip(3), [
          PrintStage.printing,
          PrintStage.attention,
          PrintStage.printing,
          PrintStage.completed,
        ]);
        expect(
          steps.firstWhere((s) => s.stage == PrintStage.attention).reasons,
          ['media-empty-error'],
        );
      },
    );

    test('reports a job the printer gave up on', () async {
      printer
        ..jobStates = [8]
        ..stoppedReasons = ['document-format-error'];

      final steps = await run();

      expect(steps.last.stage, PrintStage.failed);
      expect(steps.last.errorCode, 'ipp.job-aborted');
      expect(steps.last.errorMessage, 'document-format-error');
    });

    test('takes a job the printer has forgotten as done', () async {
      printer.remembersJobs = false;

      expect((await run()).last.stage, PrintStage.completed);
    });

    test('keeps following through a printer that goes quiet', () async {
      var asked = 0;
      http.device = (request) {
        final answer = printer.answer(request);
        if (printer.operations.last == IppOperation.getJobAttributes) {
          asked++;
          if (asked == 1) throw PrinterUnreachable(request.uri, 'busy');
          if (asked == 2) {
            return FakeAnswer.ipp(
              ippResponse(status: IppStatus.serverErrorBusy),
            );
          }
        }
        return answer;
      };

      final steps = await run(connections: [ipp, ipp]);

      expect(steps.last.stage, PrintStage.completed);
      // Never sent again, however the printer answered meanwhile.
      expect(printer.jobs, hasLength(1));
    });

    test('leaves a job as printing when the printer stays quiet', () async {
      http.device = (request) {
        final answer = printer.answer(request);
        if (printer.operations.last == IppOperation.getJobAttributes) {
          throw PrinterUnreachable(request.uri, 'off');
        }
        return answer;
      };

      final steps = await run();

      expect(steps.last.stage, PrintStage.printing);
      expect(pauses, hasLength(5));
    });

    test('leaves a job as printing after watching long enough', () async {
      printer.jobStates = [5];

      final steps = await run(using: runner(watchFor: Duration.zero));

      expect(steps.last.stage, PrintStage.printing);
      expect(pauses, isEmpty);
    });
  });

  group('cancelling', () {
    test('before the document goes sends nothing', () async {
      final print = runner().start(
        connections: [ipp],
        document: document(),
        request: const PrintRequest(),
        reference: 'r',
      );
      await print.cancel();

      final steps = await print.progress.toList();

      expect(steps.last.stage, PrintStage.cancelled);
      expect(printer.jobs, isEmpty);
    });

    test('while the printer is being asked stops before sending', () async {
      late PrintRun print;
      http.device = (request) async {
        final answer = printer.answer(request);
        if (printer.operations.last == IppOperation.validateJob) {
          await print.cancel();
        }
        return answer;
      };
      print = runner().start(
        connections: [ipp],
        document: document(),
        request: const PrintRequest(),
        reference: 'r',
      );

      final steps = await print.progress.toList();

      expect(steps.last.stage, PrintStage.cancelled);
      expect(printer.jobs, isEmpty);
    });

    test('once the printer has the job cancels it there', () async {
      printer.jobStates = [5, 5, 5];
      final print = runner().start(
        connections: [ipp],
        document: document(),
        request: const PrintRequest(),
        reference: 'r',
      );
      final steps = <PrintProgress>[];

      await for (final step in print.progress) {
        steps.add(step);
        if (step.stage == PrintStage.printing) await print.cancel();
      }

      expect(steps.last.stage, PrintStage.cancelled);
      expect(printer.cancelled, hasLength(1));
    });

    test(
      'as the document goes cancels it as soon as the printer has it',
      () async {
        late PrintRun print;
        printer
          ..jobStates = [5]
          ..onDocument = (_) => print.cancel();
        print = runner().start(
          connections: [ipp],
          document: document(),
          request: const PrintRequest(),
          reference: 'r',
        );

        final steps = await print.progress.toList();

        expect(steps.last.stage, PrintStage.cancelled);
        expect(printer.cancelled, hasLength(1));
      },
    );

    test('does not mind a printer that will not cancel', () async {
      printer.jobStates = [5, 9];
      late PrintRun print;
      http.device = (request) {
        final answer = printer.answer(request);
        if (printer.cancelled.isNotEmpty) {
          printer.cancelled.clear();
          printer.jobStates = [9];
          throw PrinterUnreachable(request.uri, 'busy');
        }
        return answer;
      };
      print = runner().start(
        connections: [ipp],
        document: document(),
        request: const PrintRequest(),
        reference: 'r',
      );

      final steps = <PrintProgress>[];
      await for (final step in print.progress) {
        steps.add(step);
        if (step.stage == PrintStage.printing) await print.cancel();
      }

      expect(steps.last.stage, PrintStage.completed);
    });
  });

  test('requests and progress compare by value', () {
    PrintRequest request(int copies) => PrintRequest(copies: copies);
    PrintProgress progress(PrintStage stage) => PrintProgress(stage);

    expect(request(2), request(2));
    expect(request(2), isNot(request(3)));
    expect(progress(PrintStage.sending), progress(PrintStage.sending));
    expect(progress(PrintStage.sending), isNot(progress(PrintStage.failed)));
  });

  test('waits a real moment, and spools to the system, by default', () async {
    printer.formats = ['image/pwg-raster'];
    final real = PrintRunner(
      http: http,
      pollInterval: const Duration(milliseconds: 1),
    );

    final steps = await real
        .start(
          connections: [ipp],
          document: document(),
          request: const PrintRequest(),
          reference: 'defaults',
        )
        .progress
        .toList();

    expect(steps.last.stage, PrintStage.completed);
    expect(real.watchFor, const Duration(minutes: 10));
  });
}
