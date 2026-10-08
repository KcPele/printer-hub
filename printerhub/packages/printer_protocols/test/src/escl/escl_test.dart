import 'dart:convert';

import 'package:printer_protocols/printer_protocols.dart';
import 'package:printer_protocols/testing.dart';
import 'package:test/test.dart';

const _ns =
    'xmlns:scan="http://schemas.hp.com/imaging/escl/2011/05/03" '
    'xmlns:pwg="http://www.pwg.org/schemas/2010/12/sm"';

String _input(String tag) =>
    '''
<scan:${tag}InputCaps>
  <scan:MaxWidth>2550</scan:MaxWidth><scan:MaxHeight>3508</scan:MaxHeight>
  <scan:SettingProfiles><scan:SettingProfile>
    <scan:ColorModes><scan:ColorMode>RGB24</scan:ColorMode><scan:ColorMode>Grayscale8</scan:ColorMode></scan:ColorModes>
    <scan:DocumentFormats>
      <pwg:DocumentFormat>application/pdf</pwg:DocumentFormat>
      <scan:DocumentFormatExt>application/pdf</scan:DocumentFormatExt>
      <scan:DocumentFormatExt>image/jpeg</scan:DocumentFormatExt>
    </scan:DocumentFormats>
    <scan:SupportedResolutions><scan:DiscreteResolutions>
      <scan:DiscreteResolution><scan:XResolution>600</scan:XResolution><scan:YResolution>600</scan:YResolution></scan:DiscreteResolution>
      <scan:DiscreteResolution><scan:XResolution>300</scan:XResolution><scan:YResolution>300</scan:YResolution></scan:DiscreteResolution>
      <scan:DiscreteResolution><scan:XResolution>auto</scan:XResolution></scan:DiscreteResolution>
    </scan:DiscreteResolutions></scan:SupportedResolutions>
  </scan:SettingProfile></scan:SettingProfiles>
</scan:${tag}InputCaps>''';

final _capabilities =
    '''
<?xml version="1.0" encoding="UTF-8"?>
<scan:ScannerCapabilities $_ns>
  <pwg:MakeAndModel>Xerox VersaLink C7130</pwg:MakeAndModel>
  <pwg:SerialNumber>SN123</pwg:SerialNumber>
  <scan:UUID>abc-123</scan:UUID>
  <scan:Platen>${_input('Platen')}</scan:Platen>
  <scan:Adf>${_input('AdfSimplex')}${_input('AdfDuplex')}</scan:Adf>
</scan:ScannerCapabilities>''';

String _status(String state, [String? feeder]) =>
    '''
<scan:ScannerStatus $_ns><pwg:State>$state</pwg:State>
${feeder == null ? '' : '<scan:AdfState>$feeder</scan:AdfState>'}
</scan:ScannerStatus>''';

void main() {
  group('EsclCapabilities.parse', () {
    test('reads the glass and the feeder', () {
      final capabilities = EsclCapabilities.parse(_capabilities);
      final platen = capabilities.platen!;

      expect(capabilities.makeAndModel, 'Xerox VersaLink C7130');
      expect(capabilities.serialNumber, 'SN123');
      expect(capabilities.uuid, 'abc-123');
      expect(platen.maxWidthMm, closeTo(215.9, 0.01));
      expect(platen.maxHeightMm, closeTo(297, 0.1));
      expect(platen.colorModes, ['RGB24', 'Grayscale8']);
      expect(platen.documentFormats, ['application/pdf', 'image/jpeg']);
      expect(platen.resolutionsDpi, [300, 600]);
      expect(capabilities.feeder, isNotNull);
      expect(capabilities.feederDuplex, isTrue);
    });

    test('reads a flatbed with no feeder', () {
      final capabilities = EsclCapabilities.parse(
        '<scan:ScannerCapabilities $_ns><scan:Platen>${_input('Platen')}'
        '</scan:Platen></scan:ScannerCapabilities>',
      );

      expect(capabilities.platen, isNotNull);
      expect(capabilities.feeder, isNull);
      expect(capabilities.feederDuplex, isFalse);
      expect(capabilities.makeAndModel, isNull);
    });

    test('reads a sheet-fed scanner with no glass', () {
      final capabilities = EsclCapabilities.parse(
        [
          '<scan:ScannerCapabilities $_ns>',
          '<pwg:MakeAndModel> </pwg:MakeAndModel>',
          '<scan:Adf><scan:AdfSimplexInputCaps></scan:AdfSimplexInputCaps></scan:Adf>',
          '</scan:ScannerCapabilities>',
        ].join(),
      );

      expect(capabilities.platen, isNull);
      expect(capabilities.makeAndModel, isNull);
      expect(capabilities.feeder!.maxWidthMm, 0);
      expect(capabilities.feeder!.resolutionsDpi, isEmpty);
      expect(capabilities.feederDuplex, isFalse);
    });
  });

  group('EsclStatus.parse', () {
    test('reads each scanner state', () {
      expect(EsclStatus.parse(_status('Idle')).state, EsclScannerState.idle);
      expect(
        EsclStatus.parse(_status('Processing')).state,
        EsclScannerState.processing,
      );
      expect(
        EsclStatus.parse(_status('Testing')).state,
        EsclScannerState.processing,
      );
      expect(
        EsclStatus.parse(_status('Stopped')).state,
        EsclScannerState.stopped,
      );
      expect(EsclStatus.parse(_status('Down')).state, EsclScannerState.down);
      expect(
        EsclStatus.parse(_status('Dancing')).state,
        EsclScannerState.unknown,
      );
    });

    test('reads the feeder', () {
      final empty = EsclStatus.parse(_status('Idle', 'ScannerAdfEmpty'));
      final jammed = EsclStatus.parse(_status('Stopped', 'ScannerAdfJam'));
      final none = EsclStatus.parse(_status('Idle'));

      expect(empty.feederEmpty, isTrue);
      expect(empty.feederJammed, isFalse);
      expect(empty.feederLoaded, isFalse);
      expect(jammed.feederJammed, isTrue);
      expect(none.feederState, isNull);
      expect(none.feederEmpty, isFalse);
      expect(
        EsclStatus.parse(_status('Idle', 'ScannerAdfLoaded')).feederLoaded,
        isTrue,
      );
      expect(
        EsclStatus.parse(_status('Stopped', 'ScannerAdfDoorOpen')).feederOpen,
        isTrue,
      );
    });
  });

  group('EsclScanSettings.toXml', () {
    test('asks for an A4 colour PDF from the glass by default', () {
      final xml = const EsclScanSettings().toXml();

      expect(xml, contains('<pwg:Version>2.0</pwg:Version>'));
      expect(xml, contains('<pwg:InputSource>Platen</pwg:InputSource>'));
      expect(xml, contains('<scan:ColorMode>RGB24</scan:ColorMode>'));
      expect(xml, contains('<scan:XResolution>300</scan:XResolution>'));
      expect(xml, contains('<pwg:Width>2480</pwg:Width>'));
      expect(xml, contains('<pwg:Height>3508</pwg:Height>'));
      expect(
        xml,
        contains('<pwg:DocumentFormat>application/pdf</pwg:DocumentFormat>'),
      );
      expect(xml, isNot(contains('DocumentFormatExt')));
      expect(xml, isNot(contains('Duplex')));
      expect(xml, contains('xmlns:scan='));
    });

    test('puts the settings in the order scanners read them in', () {
      final xml = const EsclScanSettings(
        fromFeeder: true,
        useDocumentFormatExt: true,
      ).toXml();
      final order = [
        'pwg:Version',
        'pwg:ScanRegions',
        'pwg:ContentRegionUnits',
        'pwg:XOffset',
        'pwg:YOffset',
        'pwg:Width',
        'pwg:Height',
        'pwg:InputSource',
        'scan:ColorMode',
        'pwg:DocumentFormat',
        'scan:DocumentFormatExt',
        'scan:XResolution',
        'scan:YResolution',
        'scan:Duplex',
      ].map((name) => xml.indexOf('<$name>')).toList();

      expect(order, everyElement(isNonNegative));
      expect(order, [...order]..sort());
    });

    test('asks for both sides from the feeder', () {
      final xml = const EsclScanSettings(
        fromFeeder: true,
        duplex: true,
        colorMode: 'Grayscale8',
        resolutionDpi: 600,
        documentFormat: 'image/jpeg',
      ).toXml();

      expect(xml, contains('<pwg:InputSource>Feeder</pwg:InputSource>'));
      expect(xml, contains('<scan:Duplex>true</scan:Duplex>'));
      expect(xml, contains('<scan:ColorMode>Grayscale8</scan:ColorMode>'));
      expect(xml, contains('<scan:YResolution>600</scan:YResolution>'));
      expect(xml, contains('image/jpeg'));
    });
  });

  group('EsclInput.settings fits a choice to what the scanner offers', () {
    final platen = EsclCapabilities.parse(_capabilities).platen!;

    test('keeps a choice the scanner offers', () {
      final settings = platen.settings(fromFeeder: false);

      expect(settings.colorMode, 'RGB24');
      expect(settings.resolutionDpi, 300);
      expect(settings.documentFormat, 'application/pdf');
      expect(settings.widthMm, 210);
      expect(settings.heightMm, closeTo(297, 0.1));
      expect(settings.useDocumentFormatExt, isTrue);
      expect(settings.duplex, isFalse);
    });

    test('takes the nearest resolution and the largest area', () {
      final settings = platen.settings(
        fromFeeder: true,
        duplex: true,
        resolutionDpi: 400,
        widthMm: 300,
        heightMm: 500,
      );

      expect(settings.resolutionDpi, 300);
      expect(settings.widthMm, closeTo(215.9, 0.01));
      expect(settings.heightMm, closeTo(297, 0.1));
      expect(settings.duplex, isTrue);
      expect(
        platen.settings(fromFeeder: false, resolutionDpi: 1200).resolutionDpi,
        600,
      );
    });

    test('never asks the glass for both sides', () {
      expect(platen.settings(fromFeeder: false, duplex: true).duplex, isFalse);
    });

    test('falls back to grey, and to a format the scanner has', () {
      const basic = EsclInput(
        maxWidthMm: 0,
        maxHeightMm: 0,
        colorModes: ['BlackAndWhite1', 'Grayscale8'],
        documentFormats: ['image/jpeg', 'image/tiff'],
        resolutionsDpi: [],
      );

      final settings = basic.settings(fromFeeder: false, resolutionDpi: 200);

      expect(settings.colorMode, 'Grayscale8');
      expect(settings.documentFormat, 'image/jpeg');
      expect(settings.resolutionDpi, 200);
      expect(settings.widthMm, 210);
      expect(settings.useDocumentFormatExt, isFalse);
      expect(
        basic.settings(fromFeeder: false, color: false).colorMode,
        'Grayscale8',
      );
    });

    test('copes with a scanner that lists almost nothing', () {
      const bare = EsclInput(
        maxWidthMm: 100,
        maxHeightMm: 100,
        colorModes: [],
        documentFormats: ['image/tiff'],
        resolutionsDpi: [150],
      );

      final settings = bare.settings(fromFeeder: false);

      expect(settings.colorMode, 'RGB24');
      expect(settings.documentFormat, 'image/tiff');
      expect(settings.resolutionDpi, 150);
      expect(settings.widthMm, 100);

      const only = EsclInput(
        maxWidthMm: 100,
        maxHeightMm: 100,
        colorModes: ['Other'],
        documentFormats: [],
        resolutionsDpi: [],
      );
      expect(only.settings(fromFeeder: false).colorMode, 'Other');
      expect(
        only.settings(fromFeeder: false).documentFormat,
        'application/pdf',
      );
    });
  });

  group('EsclQuirks', () {
    test('most scanners need nothing special', () {
      for (final model in ['Xerox VersaLink C7130', null, '']) {
        final quirks = EsclQuirks.forModel(model);
        expect(quirks.retryWhenNotFound, isFalse);
        expect(quirks.statusBeforeNextPage, isFalse);
        expect(quirks.pauseBetweenPages, isFalse);
        expect(quirks.localhostHostHeader, isFalse);
      }
    });

    test('knows the scanners that do', () {
      expect(EsclQuirks.forModel('B215').retryWhenNotFound, isTrue);
      expect(EsclQuirks.forModel('WorkCentre 3345').retryWhenNotFound, isTrue);
      expect(EsclQuirks.forModel('RICOH').statusBeforeNextPage, isTrue);
      expect(
        EsclQuirks.forModel('Brother MFC-L2710DW series').pauseBetweenPages,
        isTrue,
      );
      expect(
        EsclQuirks.forModel('HP LaserJet MFP M630').localhostHostHeader,
        isTrue,
      );
    });
  });

  group('EsclClient', () {
    late FakePrinterHttp http;
    late EsclClient client;
    late List<Duration> pauses;

    EsclClient make({EsclQuirks quirks = EsclQuirks.none}) {
      return EsclClient(
        baseUri: Uri.parse('http://192.168.1.40/eSCL'),
        http: http,
        quirks: quirks,
        startAttempts: 3,
        pageAttempts: 4,
        pause: (duration) async => pauses.add(duration),
      );
    }

    EsclScan scan({bool fromFeeder = false, int pagesReceived = 0}) {
      return EsclScan(
        uri: Uri.parse('http://192.168.1.40/eSCL/ScanJobs/job-1'),
        fromFeeder: fromFeeder,
      )..pagesReceived = pagesReceived;
    }

    FakeAnswer page() => FakeAnswer(
      200,
      body: utf8.encode('%PDF-page'),
      headers: const {'content-type': 'application/pdf'},
    );

    /// Answers with each of [answers] in turn, then the last one for ever.
    void answerInTurn(List<FakeAnswer> answers) {
      var next = 0;
      http.device = (_) =>
          answers[next < answers.length ? next++ : answers.length - 1];
    }

    setUp(() {
      pauses = [];
      http = FakePrinterHttp((_) => FakeAnswer.text(200, _capabilities));
      client = make();
    });

    test('finds eSCL at the usual place on a host', () async {
      await EsclClient.forHost('192.168.1.40', http: http).capabilities();

      expect(
        http.requests.single.uri,
        Uri.parse('http://192.168.1.40/eSCL/ScannerCapabilities'),
      );
      expect(
        EsclClient.forHost(
          's.local',
          http: http,
          secure: true,
          port: 443,
        ).baseUri,
        Uri.parse('https://s.local/eSCL'),
      );
      expect(
        EsclClient(
          baseUri: Uri.parse('http://h:8080/eSCL/'),
          http: http,
        ).baseUri,
        Uri.parse('http://h:8080/eSCL'),
      );
    });

    test('capabilities and status are read', () async {
      expect(
        (await client.capabilities()).makeAndModel,
        'Xerox VersaLink C7130',
      );

      http.device = (_) =>
          FakeAnswer.text(200, _status('Idle', 'ScannerAdfLoaded'));
      expect((await client.status()).state, EsclScannerState.idle);
      expect(http.requests.last.uri.path, '/eSCL/ScannerStatus');
    });

    test('a device without eSCL says so', () async {
      http.device = (_) => FakeAnswer.text(404, 'eSCL is not enabled');

      await expectLater(
        client.capabilities(),
        throwsA(
          isA<EsclException>()
              .having((e) => e.notSupported, 'notSupported', isTrue)
              .having((e) => e.busy, 'busy', isFalse)
              .having((e) => e.message, 'message', 'eSCL is not enabled')
              .having((e) => '$e', 'toString', contains('HTTP 404')),
        ),
      );
    });

    test('a web page instead of eSCL counts as not supported', () async {
      http.device = (_) => FakeAnswer.text(200, 'Welcome to your printer');

      await expectLater(
        client.capabilities(),
        throwsA(
          isA<EsclException>().having((e) => e.notSupported, 'ns', isTrue),
        ),
      );

      http.device = (_) => const FakeAnswer(200);
      await expectLater(client.status(), throwsA(isA<EsclException>()));
    });

    group('startScan', () {
      test('posts the settings and returns the job', () async {
        http.device = (_) => const FakeAnswer(
          201,
          headers: {'location': 'http://192.168.1.40/eSCL/ScanJobs/job-1'},
        );

        final job = await client.startScan(
          const EsclScanSettings(fromFeeder: true),
        );

        final request = http.requests.single;
        expect(job.uri, Uri.parse('http://192.168.1.40/eSCL/ScanJobs/job-1'));
        expect(job.fromFeeder, isTrue);
        expect(job.pagesReceived, 0);
        expect(request.method, 'POST');
        expect(request.uri.path, '/eSCL/ScanJobs');
        expect(request.headers, {'Content-Type': 'text/xml'});
        expect(
          request.text,
          contains('<pwg:InputSource>Feeder</pwg:InputSource>'),
        );
        expect(request.contentLength, request.body.length);
      });

      test('believes only the path of the address it is given', () async {
        Future<Uri> jobAt(String location) async {
          http.device = (_) => FakeAnswer(201, headers: {'location': location});
          return (await client.startScan(const EsclScanSettings())).uri;
        }

        final expected = Uri.parse('http://192.168.1.40/eSCL/ScanJobs/job-2');
        // A path.
        expect(await jobAt('/eSCL/ScanJobs/job-2'), expected);
        // A name the phone cannot find, on another port.
        expect(
          await jobAt('https://XRX9C934E5E.local:8443/eSCL/ScanJobs/job-2/'),
          expected,
        );
        // An address cut short, as the Xerox B215 sends.
        expect(await jobAt('http://[fe80/eSCL/ScanJobs/job-2'), expected);
        // Only the job's own name.
        expect(await jobAt('job-2'), expected);
        expect(await jobAt('/eSCL/ScanJobs/job-2?x=1'), expected);
      });

      test('asks again while the scanner is busy', () async {
        answerInTurn([
          const FakeAnswer(503),
          const FakeAnswer(503),
          const FakeAnswer(201, headers: {'location': '/eSCL/ScanJobs/j'}),
        ]);

        final job = await client.startScan(const EsclScanSettings());

        expect(job.uri.path, '/eSCL/ScanJobs/j');
        expect(http.requests, hasLength(3));
        expect(pauses, [
          const Duration(seconds: 1),
          const Duration(seconds: 1),
        ]);
      });

      test('gives up on a scanner that stays busy', () async {
        http.device = (_) => const FakeAnswer(503);

        await expectLater(
          client.startScan(const EsclScanSettings()),
          throwsA(
            isA<EsclException>()
                .having((e) => e.busy, 'busy', isTrue)
                .having((e) => e.message, 'message', isNull)
                .having((e) => '$e', 'toString', 'EsclException(HTTP 503)'),
          ),
        );
        expect(http.requests, hasLength(3));
      });

      test('reports why the scanner refused', () async {
        http.device = (_) =>
            FakeAnswer.text(409, 'The document feeder is empty');
        await expectLater(
          client.startScan(const EsclScanSettings(fromFeeder: true)),
          throwsA(
            isA<EsclException>()
                .having((e) => e.notReady, 'notReady', isTrue)
                .having(
                  (e) => e.message,
                  'message',
                  contains('feeder is empty'),
                ),
          ),
        );
        expect(pauses, isEmpty);

        // Created, but without saying where: nothing to fetch pages from.
        http.device = (_) => const FakeAnswer(201);
        await expectLater(
          client.startScan(const EsclScanSettings()),
          throwsA(isA<EsclException>()),
        );
        http.device = (_) => const FakeAnswer(201, headers: {'location': ''});
        await expectLater(
          client.startScan(const EsclScanSettings()),
          throwsA(isA<EsclException>()),
        );
      });

      test('addresses the HP models that insist on it as localhost', () async {
        http.device = (_) =>
            const FakeAnswer(201, headers: {'location': '/eSCL/ScanJobs/j'});

        await make(quirks: EsclQuirks.forModel('HP LaserJet MFP M630'))
            .startScan(const EsclScanSettings());

        expect(http.requests.single.headers['Host'], 'localhost');
      });
    });

    group('nextDocument', () {
      test('streams a page and counts it', () async {
        http.device = (_) => page();
        final job = scan();

        final document = await client.nextDocument(job);
        final bytes = await document!.bytes.expand((chunk) => chunk).toList();

        expect(utf8.decode(bytes), '%PDF-page');
        expect(document.contentType, 'application/pdf');
        expect(job.pagesReceived, 1);
        expect(
          http.requests.single.uri.path,
          '/eSCL/ScanJobs/job-1/NextDocument',
        );
      });

      test('waits for a page that is still being scanned', () async {
        answerInTurn([const FakeAnswer(503), const FakeAnswer(503), page()]);

        expect(await client.nextDocument(scan()), isNotNull);
        expect(pauses, hasLength(2));
      });

      test('gives up on a page that never comes', () async {
        http.device = (_) => const FakeAnswer(503);

        await expectLater(
          client.nextDocument(scan()),
          throwsA(isA<EsclException>().having((e) => e.busy, 'busy', isTrue)),
        );
        expect(http.requests, hasLength(4));
        expect(pauses, hasLength(3));
      });

      test('the feeder is finished when the scanner has no more', () async {
        http.device = (_) => const FakeAnswer(404);
        expect(
          await client.nextDocument(scan(fromFeeder: true, pagesReceived: 3)),
          isNull,
        );

        // An empty feeder is no pages, not a failure.
        http.device = (_) => const FakeAnswer(410);
        expect(await client.nextDocument(scan(fromFeeder: true)), isNull);
        expect(pauses, isEmpty);
      });

      test('the glass is finished after its one page', () async {
        // Whatever the scanner answers, and without waiting on it.
        for (final status in [404, 410, 503, 500]) {
          http.device = (_) => FakeAnswer(status);
          expect(
            await client.nextDocument(scan(pagesReceived: 1)),
            isNull,
            reason: 'HTTP $status',
          );
        }
        expect(pauses, isEmpty);
      });

      test('a scan from the glass that yields nothing has failed', () async {
        http.device = (_) => const FakeAnswer(404);

        await expectLater(
          client.nextDocument(scan()),
          throwsA(
            isA<EsclException>().having((e) => e.httpStatus, 'status', 404),
          ),
        );
      });

      test('reports a scanner error', () async {
        http.device = (_) => FakeAnswer.text(500, 'Lamp failure');

        await expectLater(
          client.nextDocument(scan(fromFeeder: true)),
          throwsA(
            isA<EsclException>()
                .having((e) => e.httpStatus, 'status', 500)
                .having((e) => e.message, 'message', 'Lamp failure'),
          ),
        );
      });

      test('waits on "not found" for the scanners that mean busy', () async {
        final patient = make(quirks: EsclQuirks.forModel('B215'));
        answerInTurn([const FakeAnswer(404), const FakeAnswer(410), page()]);

        expect(await patient.nextDocument(scan(fromFeeder: true)), isNotNull);
        expect(pauses, hasLength(2));

        // Still "not found" after every try: the feeder is empty.
        http.device = (_) => const FakeAnswer(404);
        expect(
          await patient.nextDocument(scan(fromFeeder: true, pagesReceived: 1)),
          isNull,
        );
      });

      test('asks a Ricoh how it is before each page', () async {
        final ricoh = make(quirks: EsclQuirks.forModel('RICOH'));
        http.device = (request) => request.uri.path.endsWith('ScannerStatus')
            ? FakeAnswer.text(200, _status('Processing'))
            : page();

        await ricoh.nextDocument(scan());

        expect(http.requests.map((r) => r.uri.path), [
          '/eSCL/ScannerStatus',
          '/eSCL/ScanJobs/job-1/NextDocument',
        ]);

        // A status that fails does not stop the scan.
        http.device = (request) => request.uri.path.endsWith('ScannerStatus')
            ? const FakeAnswer(500)
            : page();
        expect(await ricoh.nextDocument(scan()), isNotNull);
      });

      test('gives a Brother feeder a moment between pages', () async {
        final brother = make(
          quirks: EsclQuirks.forModel('Brother MFC-L2710DW series'),
        );
        http.device = (_) => page();
        final job = scan(fromFeeder: true);

        await brother.nextDocument(job);
        expect(pauses, isEmpty);
        await brother.nextDocument(job);
        expect(pauses, hasLength(1));
        expect(pauses.single, lessThanOrEqualTo(const Duration(seconds: 1)));

        // Not from the glass, which has no next page.
        pauses.clear();
        await brother.nextDocument(scan());
        expect(pauses, isEmpty);
      });

      test('never pauses longer than one retry between pages', () async {
        final brother = EsclClient(
          baseUri: Uri.parse('http://192.168.1.40/eSCL'),
          http: http,
          quirks: EsclQuirks.forModel('Brother DCP'),
          retryPause: Duration.zero,
          pause: (duration) async => pauses.add(duration),
        );
        http.device = (_) => page();
        final job = scan(fromFeeder: true);

        await brother.nextDocument(job);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await brother.nextDocument(job);

        expect(pauses, [Duration.zero]);
      });
    });

    test('cancel ends a job, and a forgotten job is not an error', () async {
      final job = scan();

      http.device = (_) => const FakeAnswer(200);
      await client.cancel(job);
      expect(http.requests.single.method, 'DELETE');
      expect(http.requests.single.uri, job.uri);

      for (final status in [404, 410]) {
        http.device = (_) => FakeAnswer(status);
        await client.cancel(job);
      }

      http.device = (_) => const FakeAnswer(500);
      await expectLater(client.cancel(job), throwsA(isA<EsclException>()));
    });

    test('waits a real moment when no other way to wait is given', () async {
      final real = EsclClient(
        baseUri: Uri.parse('http://192.168.1.40/eSCL'),
        http: http,
        retryPause: const Duration(milliseconds: 1),
      );
      answerInTurn([const FakeAnswer(503), page()]);

      expect(await real.nextDocument(scan()), isNotNull);
      expect(real.startAttempts, 10);
      expect(real.pageAttempts, 30);
    });
  });
}
