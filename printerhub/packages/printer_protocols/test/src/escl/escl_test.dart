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
      expect(jammed.feederJammed, isTrue);
      expect(none.feederState, isNull);
      expect(none.feederEmpty, isFalse);
    });
  });

  group('EsclScanSettings.toXml', () {
    test('asks for an A4 colour PDF from the glass by default', () {
      final xml = const EsclScanSettings().toXml();

      expect(xml, contains('<pwg:InputSource>Platen</pwg:InputSource>'));
      expect(xml, contains('<scan:ColorMode>RGB24</scan:ColorMode>'));
      expect(xml, contains('<scan:XResolution>300</scan:XResolution>'));
      expect(xml, contains('<pwg:Width>2480</pwg:Width>'));
      expect(xml, contains('<pwg:Height>3508</pwg:Height>'));
      expect(
        xml,
        contains('<pwg:DocumentFormat>application/pdf</pwg:DocumentFormat>'),
      );
      expect(
        xml,
        contains(
          '<scan:DocumentFormatExt>application/pdf</scan:DocumentFormatExt>',
        ),
      );
      expect(xml, isNot(contains('Duplex')));
      expect(xml, contains('xmlns:scan='));
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

  group('EsclClient', () {
    late FakePrinterHttp http;
    late EsclClient client;

    setUp(() {
      http = FakePrinterHttp((_) => FakeAnswer.text(200, _capabilities));
      client = EsclClient.forHost('192.168.1.40', http: http);
    });

    test('finds eSCL at the usual place on a host', () async {
      await client.capabilities();

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

    test('startScan posts the settings and returns the job address', () async {
      http.device = (_) => const FakeAnswer(
        201,
        headers: {'location': 'http://192.168.1.40/eSCL/ScanJobs/job-1'},
      );

      final job = await client.startScan(const EsclScanSettings());

      final request = http.requests.single;
      expect(job, Uri.parse('http://192.168.1.40/eSCL/ScanJobs/job-1'));
      expect(request.method, 'POST');
      expect(request.uri.path, '/eSCL/ScanJobs');
      expect(request.headers['Content-Type'], 'text/xml');
      expect(
        request.text,
        contains('<pwg:InputSource>Platen</pwg:InputSource>'),
      );
      expect(request.contentLength, request.body.length);
    });

    test('startScan accepts a job address given as a path', () async {
      http.device = (_) =>
          const FakeAnswer(201, headers: {'location': '/eSCL/ScanJobs/job-2'});

      expect(
        await client.startScan(const EsclScanSettings()),
        Uri.parse('http://192.168.1.40/eSCL/ScanJobs/job-2'),
      );
    });

    test('startScan reports why the scanner refused', () async {
      http.device = (_) => FakeAnswer.text(409, 'The document feeder is empty');
      await expectLater(
        client.startScan(const EsclScanSettings(fromFeeder: true)),
        throwsA(
          isA<EsclException>()
              .having((e) => e.notReady, 'notReady', isTrue)
              .having((e) => e.message, 'message', contains('feeder is empty')),
        ),
      );

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

      // Created, but without saying where: nothing to fetch pages from.
      http.device = (_) => const FakeAnswer(201);
      await expectLater(
        client.startScan(const EsclScanSettings()),
        throwsA(isA<EsclException>()),
      );
    });

    test('nextDocument streams a page, then says there are no more', () async {
      final job = Uri.parse('http://192.168.1.40/eSCL/ScanJobs/job-1');
      http.device = (_) => FakeAnswer(
        200,
        body: utf8.encode('%PDF-page'),
        headers: const {'content-type': 'application/pdf'},
      );

      final page = await client.nextDocument(job);
      final bytes = await page!.bytes.expand((chunk) => chunk).toList();

      expect(utf8.decode(bytes), '%PDF-page');
      expect(page.contentType, 'application/pdf');
      expect(
        http.requests.single.uri.path,
        '/eSCL/ScanJobs/job-1/NextDocument',
      );

      http.device = (_) => const FakeAnswer(404);
      expect(await client.nextDocument(job), isNull);
    });

    test('nextDocument reports a scanner error', () async {
      http.device = (_) => FakeAnswer.text(500, 'Lamp failure');

      await expectLater(
        client.nextDocument(Uri.parse('http://h/eSCL/ScanJobs/j')),
        throwsA(
          isA<EsclException>().having((e) => e.httpStatus, 'status', 500),
        ),
      );
    });

    test('cancel stops a job, and a finished job is not an error', () async {
      final job = Uri.parse('http://192.168.1.40/eSCL/ScanJobs/job-1');

      http.device = (_) => const FakeAnswer(200);
      await client.cancel(job);
      expect(http.requests.single.method, 'DELETE');
      expect(http.requests.single.uri, job);

      http.device = (_) => const FakeAnswer(404);
      await client.cancel(job);

      http.device = (_) => const FakeAnswer(500);
      await expectLater(client.cancel(job), throwsA(isA<EsclException>()));
    });
  });
}
