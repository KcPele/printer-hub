import 'dart:async';
import 'dart:io';

import 'package:connection_engine/connection_engine.dart';
import 'package:printer_protocols/printer_protocols.dart';
import 'package:printer_protocols/testing.dart';
import 'package:test/test.dart';

const _ns =
    'xmlns:scan="http://schemas.hp.com/imaging/escl/2011/05/03" '
    'xmlns:pwg="http://www.pwg.org/schemas/2010/12/sm"';

/// A scanner that answers eSCL on any connection, and keeps what it was
/// asked.
class _Scanner {
  String model = 'Test Scanner';
  bool hasFeeder = true;
  bool feederDuplex = true;
  List<String> formats = ['image/jpeg', 'application/pdf'];

  /// The pages a scan gives, and the type each is said to be.
  List<String> pages = ['page one'];
  String? contentType = 'image/jpeg';

  /// The status `ScanJobs` answers with, when it is not 201.
  int? startStatus;

  /// What `ScannerStatus` says of the feeder.
  String feederState = 'ScannerAdfLoaded';
  bool statusFails = false;

  /// Called before each page is handed over. Throw to drop the connection.
  void Function(int page)? onPage;

  final List<String> settings = [];
  int deleted = 0;
  int _served = 0;

  String _input(String name) => [
    '<scan:$name>',
    '<scan:MaxWidth>2550</scan:MaxWidth><scan:MaxHeight>3508</scan:MaxHeight>',
    '<scan:ColorMode>RGB24</scan:ColorMode>',
    '<scan:ColorMode>Grayscale8</scan:ColorMode>',
    for (final format in formats)
      '<pwg:DocumentFormat>$format</pwg:DocumentFormat>',
    '<scan:XResolution>300</scan:XResolution>',
    '<scan:XResolution>600</scan:XResolution>',
    '</scan:$name>',
  ].join();

  FakeAnswer answer(SentRequest request) {
    final path = request.uri.path;
    if (path.endsWith('/ScannerCapabilities')) {
      return FakeAnswer.text(
        200,
        [
          '<scan:ScannerCapabilities $_ns>',
          '<pwg:MakeAndModel>$model</pwg:MakeAndModel>',
          '<scan:Platen>${_input('PlatenInputCaps')}</scan:Platen>',
          if (hasFeeder) ...[
            '<scan:Adf>${_input('AdfSimplexInputCaps')}',
            if (feederDuplex) _input('AdfDuplexInputCaps'),
            '</scan:Adf>',
          ],
          '</scan:ScannerCapabilities>',
        ].join(),
      );
    }
    if (path.endsWith('/ScannerStatus')) {
      if (statusFails) return const FakeAnswer(500);
      return FakeAnswer.text(
        200,
        [
          '<scan:ScannerStatus $_ns><pwg:State>Idle</pwg:State>',
          '<scan:AdfState>$feederState</scan:AdfState></scan:ScannerStatus>',
        ].join(),
      );
    }
    if (path.endsWith('/ScanJobs')) {
      settings.add(String.fromCharCodes(request.body));
      final refused = startStatus;
      if (refused != null) return FakeAnswer.text(refused, 'Refused');
      _served = 0;
      return const FakeAnswer(
        201,
        headers: {'location': 'http://scanner.local/eSCL/ScanJobs/42'},
      );
    }
    if (request.method == 'DELETE') {
      deleted++;
      return const FakeAnswer(200);
    }
    if (_served >= pages.length) return const FakeAnswer(404);
    onPage?.call(_served + 1);
    return FakeAnswer.text(
      200,
      pages[_served++],
      headers: {'content-type': ?contentType},
    );
  }
}

final _escl = DeviceConnection(
  type: 'escl',
  uri: Uri.parse('http://192.168.1.40/eSCL'),
);
final _secure = DeviceConnection(
  type: 'escl',
  uri: Uri.parse('https://192.168.1.40/eSCL'),
);
final _ipp = DeviceConnection(
  type: 'ipp',
  uri: Uri.parse('ipp://192.168.1.40/ipp/print'),
);

void main() {
  late _Scanner scanner;
  late FakePrinterHttp http;
  late Directory directory;
  late ScanRunner runner;

  setUp(() {
    scanner = _Scanner();
    http = FakePrinterHttp(scanner.answer);
    directory = Directory.systemTemp.createTempSync('scan_runner_test');
    addTearDown(() => directory.deleteSync(recursive: true));
    runner = ScanRunner(http: http, directory: directory, pause: (_) async {});
  });

  Future<List<ScanProgress>> scan({
    ScanRequest request = const ScanRequest(),
    List<DeviceConnection>? connections,
  }) {
    return runner
        .start(connections: connections ?? [_ipp, _escl], request: request)
        .progress
        .toList();
  }

  List<ScanStage> stages(List<ScanProgress> steps) => [
    for (final step in steps) step.stage,
  ];

  group('a scan from the glass', () {
    test('keeps the page in a file, and ends the job', () async {
      final steps = await scan();

      expect(stages(steps), [
        ScanStage.connecting,
        ScanStage.scanning,
        ScanStage.scanning,
        ScanStage.completed,
      ]);
      final page = steps.last.pages.single;
      expect(page.mimeType, 'image/jpeg');
      expect(page.file.path, startsWith(directory.path));
      expect(page.file.path, endsWith('-1.jpg'));
      expect(page.file.readAsStringSync(), 'page one');
      expect(steps.last.connection, _escl);
      expect(steps.last.isFinal, isTrue);
      expect(steps.first.isFinal, isFalse);
      expect(scanner.deleted, 1);
      expect(scanner.settings.single, contains('Platen'));
      expect(scanner.settings.single, contains('image/jpeg'));
      expect(scanner.settings.single, contains('RGB24'));
    });

    test('asks for what was chosen, as far as the scanner offers it', () async {
      scanner
        ..formats = ['application/pdf']
        ..contentType = 'application/pdf; charset=binary';

      final steps = await scan(
        request: const ScanRequest(
          color: false,
          resolutionDpi: 500,
          widthMm: 148,
          heightMm: 210,
        ),
      );

      final sent = scanner.settings.single;
      expect(sent, contains('Grayscale8'));
      expect(sent, contains('<scan:XResolution>600</scan:XResolution>'));
      expect(sent, contains('application/pdf'));
      expect(sent, contains('<pwg:Width>1748</pwg:Width>'));
      expect(steps.last.pages.single.mimeType, 'application/pdf');
      expect(steps.last.pages.single.file.path, endsWith('.pdf'));
    });

    test('takes the page for what was asked when the scanner does not '
        'say what it is', () async {
      scanner.contentType = null;

      final steps = await scan();

      expect(steps.last.pages.single.mimeType, 'image/jpeg');
    });
  });

  group('a scan from the feeder', () {
    test('keeps every sheet, in order', () async {
      scanner.pages = ['one', 'two', 'three'];

      final steps = await scan(
        request: const ScanRequest(source: 'adf', duplex: true),
      );

      expect(steps.last.stage, ScanStage.completed);
      expect(
        [for (final page in steps.last.pages) page.file.readAsStringSync()],
        ['one', 'two', 'three'],
      );
      // The pages grow one at a time.
      expect([for (final step in steps) step.pages.length], [0, 0, 1, 2, 3, 3]);
      expect(scanner.settings.single, contains('Feeder'));
      expect(
        scanner.settings.single,
        contains('<scan:Duplex>true</scan:Duplex>'),
      );
    });

    test('scans one side on a feeder that cannot turn the sheet', () async {
      scanner.feederDuplex = false;

      await scan(request: const ScanRequest(source: 'adf', duplex: true));

      expect(
        scanner.settings.single,
        contains('<scan:Duplex>false</scan:Duplex>'),
      );
    });

    test('says when there is no feeder', () async {
      scanner.hasFeeder = false;

      final steps = await scan(request: const ScanRequest(source: 'adf'));

      expect(steps.last.stage, ScanStage.failed);
      expect(steps.last.errorCode, 'scan.source_not_available');
      expect(scanner.settings, isEmpty);
    });

    test('says when the feeder turns out to be empty', () async {
      scanner.pages = [];

      final steps = await scan(request: const ScanRequest(source: 'adf'));

      expect(steps.last.stage, ScanStage.failed);
      expect(steps.last.errorCode, 'scan.feeder_empty');
      expect(scanner.deleted, 1);
    });

    for (final (state, code) in [
      ('ScannerAdfEmpty', 'scan.feeder_empty'),
      ('ScannerAdfJam', 'scan.feeder_jam'),
      ('ScannerAdfDoorOpen', 'scan.feeder_open'),
      ('ScannerAdfProcessing', 'scan.not_ready'),
    ]) {
      test('says why the scanner is not ready: $code', () async {
        scanner
          ..startStatus = 409
          ..feederState = state;

        final steps = await scan(request: const ScanRequest(source: 'adf'));

        expect(steps.last.stage, ScanStage.failed);
        expect(steps.last.errorCode, code);
        expect(steps.last.errorMessage, 'Refused');
      });
    }

    test('says it is not ready when it will not say why', () async {
      scanner
        ..startStatus = 409
        ..statusFails = true;

      final steps = await scan(request: const ScanRequest(source: 'adf'));

      expect(steps.last.errorCode, 'scan.not_ready');
    });
  });

  group('when the scanner refuses', () {
    test('says it is busy once it has been asked enough', () async {
      scanner.startStatus = 503;

      final steps = await scan();

      expect(steps.last.errorCode, 'scan.busy');
      expect(scanner.settings, hasLength(10));
    });

    test('passes on an answer it has no word for', () async {
      scanner.startStatus = 500;

      final steps = await scan();

      expect(steps.last.stage, ScanStage.failed);
      expect(steps.last.errorCode, 'escl.http_500');
    });

    test('ends the job when a page is refused', () async {
      scanner.pages = ['one', 'two'];
      var asked = 0;
      http.device = (request) {
        if (request.uri.path.endsWith('NextDocument') && ++asked == 2) {
          return const FakeAnswer(500);
        }
        return scanner.answer(request);
      };

      final steps = await scan(request: const ScanRequest(source: 'adf'));

      expect(steps.last.stage, ScanStage.failed);
      expect(steps.last.errorCode, 'escl.http_500');
      // The page that did arrive is kept.
      expect(steps.last.pages, hasLength(1));
      expect(scanner.deleted, 1);
    });
  });

  group('connections', () {
    test('says when the device has no way to scan', () async {
      final steps = await scan(connections: [_ipp]);

      expect(stages(steps), [ScanStage.failed]);
      expect(steps.single.errorCode, 'scan.no_connection');
      expect(http.requests, isEmpty);
    });

    test('moves on when eSCL is switched off at an address', () async {
      http.device = (request) => request.uri.scheme == 'http'
          ? const FakeAnswer(404)
          : scanner.answer(request);

      final steps = await scan(connections: [_escl, _secure]);

      expect(steps.last.stage, ScanStage.completed);
      expect(steps.last.connection, _secure);
    });

    test('says scanning is not available when it is off everywhere', () async {
      http.device = (_) => const FakeAnswer(404);

      final steps = await scan(connections: [_escl, _secure]);

      expect(steps.last.stage, ScanStage.failed);
      expect(steps.last.errorCode, 'scan.not_available');
    });

    test('moves on when nothing answers, and says so at the end', () async {
      http.device = (request) =>
          throw PrinterUnreachable(request.uri, 'nothing there');

      final steps = await scan(connections: [_escl, _secure]);

      expect(stages(steps), [
        ScanStage.connecting,
        ScanStage.connecting,
        ScanStage.failed,
      ]);
      expect(steps.last.errorCode, 'scan.unreachable');
    });

    test('does not start again elsewhere once the scanner has the job, '
        'and keeps the pages it got', () async {
      scanner
        ..pages = ['one', 'two']
        ..onPage = (page) {
          if (page == 2) throw const SocketException('gone');
        };

      final steps = await scan(
        request: const ScanRequest(source: 'adf'),
        connections: [_escl, _secure],
      );

      expect(steps.last.stage, ScanStage.failed);
      expect(steps.last.errorCode, 'scan.connection_lost');
      expect(steps.last.pages, hasLength(1));
      expect(scanner.settings, hasLength(1));
    });
  });

  group('the page', () {
    test('is dropped when it stops arriving half way', () async {
      http = _BrokenBody(scanner.answer);
      runner = ScanRunner(http: http, directory: directory);

      final steps = await scan();

      expect(steps.last.stage, ScanStage.failed);
      expect(steps.last.errorCode, 'scan.connection_lost');
      expect(steps.last.pages, isEmpty);
      expect(directory.listSync(), isEmpty);
    });

    test('says when it cannot be kept', () async {
      runner = ScanRunner(
        http: http,
        directory: Directory('${directory.path}/missing'),
      );

      final steps = await scan();

      expect(steps.last.stage, ScanStage.failed);
      expect(steps.last.errorCode, 'scan.storage');
      expect(steps.last.errorMessage, isNotEmpty);
      expect(scanner.deleted, 1);
    });

    test('goes to the system’s temporary files unless told where', () async {
      final steps = await ScanRunner(http: http)
          .start(connections: [_escl], request: const ScanRequest())
          .progress
          .toList();

      final file = steps.last.pages.single.file;
      addTearDown(file.deleteSync);
      expect(file.path, startsWith(Directory.systemTemp.path));
    });
  });

  group('cancelling', () {
    test(
      'while the scanner is being asked what it can do sends no job',
      () async {
        final run = runner.start(
          connections: [_escl],
          request: const ScanRequest(),
        );
        await run.cancel();

        final steps = await run.progress.toList();

        expect(stages(steps), [ScanStage.connecting, ScanStage.cancelled]);
        expect(scanner.settings, isEmpty);
      },
    );

    test('before the next connection is tried ends it there', () async {
      late ScanRun run;
      http.device = (request) async {
        await Future<void>.delayed(Duration.zero);
        await run.cancel();
        throw PrinterUnreachable(request.uri, 'nothing there');
      };
      run = runner.start(
        connections: [_escl, _secure],
        request: const ScanRequest(),
      );

      final steps = await run.progress.toList();

      expect(stages(steps), [ScanStage.connecting, ScanStage.cancelled]);
      expect(http.requests, hasLength(1));
    });

    test('between pages keeps the pages that arrived', () async {
      scanner.pages = ['one', 'two', 'three'];
      late ScanRun run;
      scanner.onPage = (page) {
        if (page == 2) unawaited(run.cancel());
      };
      run = runner.start(
        connections: [_escl],
        request: const ScanRequest(source: 'adf'),
      );

      final steps = await run.progress.toList();

      expect(steps.last.stage, ScanStage.cancelled);
      expect(steps.last.pages, hasLength(2));
      expect(scanner.deleted, greaterThanOrEqualTo(1));
    });

    test('is what a refusal after it counts as', () async {
      late ScanRun run;
      http.device = (request) async {
        if (request.uri.path.endsWith('NextDocument')) {
          await run.cancel();
          return const FakeAnswer(404);
        }
        return scanner.answer(request);
      };
      run = runner.start(connections: [_escl], request: const ScanRequest());

      final steps = await run.progress.toList();

      expect(steps.last.stage, ScanStage.cancelled);
    });

    test('is what a dropped connection after it counts as', () async {
      late ScanRun run;
      http.device = (request) async {
        if (request.uri.path.endsWith('NextDocument')) {
          await run.cancel();
          throw const SocketException('gone');
        }
        return scanner.answer(request);
      };
      run = runner.start(connections: [_escl], request: const ScanRequest());

      final steps = await run.progress.toList();

      expect(steps.last.stage, ScanStage.cancelled);
    });

    test('does not mind a scanner that will not end the job', () async {
      http.device = (request) => request.method == 'DELETE'
          ? const FakeAnswer(500)
          : scanner.answer(request);

      final steps = await scan();

      expect(steps.last.stage, ScanStage.completed);
    });
  });

  test('uses what the scanner’s model is known to need', () async {
    // These HP models refuse a scan addressed to them by anything else.
    scanner.model = 'HP LaserJet MFP M630';

    await scan();

    final started = http.requests.firstWhere(
      (request) => request.uri.path.endsWith('/ScanJobs'),
    );
    expect(started.headers['Host'], 'localhost');
  });

  test('requests, pages, and progress compare by value', () {
    expect(const ScanRequest(), const ScanRequest());
    expect(const ScanRequest(), isNot(const ScanRequest(source: 'adf')));
    expect(const ScanRequest(source: 'adf').fromFeeder, isTrue);
    final page = ScannedPage(file: File('a.jpg'), mimeType: 'image/jpeg');
    expect(page, ScannedPage(file: File('a.jpg'), mimeType: 'image/jpeg'));
    expect(
      ScanProgress(ScanStage.scanning, pages: [page]),
      ScanProgress(ScanStage.scanning, pages: [page]),
    );
  });
}

/// A connection whose answers break off as a page arrives.
class _BrokenBody extends FakePrinterHttp {
  new(super.device);

  @override
  Future<PrinterHttpResponse> send(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    Stream<List<int>>? body,
    int? contentLength,
  }) async {
    final response = await super.send(
      method,
      uri,
      headers: headers,
      body: body,
      contentLength: contentLength,
    );
    if (!uri.path.endsWith('NextDocument')) return response;
    return PrinterHttpResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      body: () async* {
        yield 'half a pa'.codeUnits;
        throw const SocketException('gone');
      }(),
    );
  }
}
