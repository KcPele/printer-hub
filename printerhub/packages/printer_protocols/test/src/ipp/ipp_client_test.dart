import 'dart:typed_data';

import 'package:printer_protocols/printer_protocols.dart';
import 'package:printer_protocols/testing.dart';
import 'package:test/test.dart';

void main() {
  late FakePrinterHttp http;
  late IppClient client;

  IppGroup jobGroup({int id = 5, int state = 3}) {
    return IppGroup(IppGroupTag.job, [
      IppAttribute.single('job-id', IppValueTag.integer, id),
      IppAttribute.single('job-state', IppValueTag.enumeration, state),
    ]);
  }

  /// The IPP message the client sent, and the document after it.
  IppDecoded sent([int index = 0]) => decodeIpp(http.requests[index].body);

  setUp(() {
    http = FakePrinterHttp((_) => FakeAnswer.ipp(ippResponse()));
    client = IppClient.forHost('192.168.1.40', http: http);
  });

  group('addresses', () {
    test('sends to http and names the printer with ipp', () async {
      await client.getPrinterAttributes();

      expect(http.requests.single.method, 'POST');
      expect(
        http.requests.single.uri,
        Uri.parse('http://192.168.1.40:631/ipp/print'),
      );
      expect(http.requests.single.headers['Content-Type'], 'application/ipp');
      expect(
        sent().message.group(IppGroupTag.operation)!['printer-uri']!.first,
        'ipp://192.168.1.40:631/ipp/print',
      );
    });

    test('uses https for a secure printer', () async {
      client = IppClient.forHost(
        'printer.local',
        http: http,
        secure: true,
        port: 443,
      );

      await client.getPrinterAttributes();

      expect(
        http.requests.single.uri,
        Uri.parse('https://printer.local/ipp/print'),
      );
      expect(
        sent().message.group(IppGroupTag.operation)!['printer-uri']!.first,
        'ipps://printer.local:443/ipp/print',
      );
    });

    test('accepts an http address and fills in the IPP port', () async {
      client = IppClient(
        printerUri: Uri.parse('ipp://printer.local/ipp/print'),
        http: http,
      );
      await client.getPrinterAttributes();
      expect(http.requests.last.uri.port, 631);

      client = IppClient(
        printerUri: Uri.parse('https://printer.local:8443/ipp'),
        http: http,
      );
      await client.getPrinterAttributes();
      expect(
        http.requests.last.uri,
        Uri.parse('https://printer.local:8443/ipp'),
      );
      expect(
        sent(1).message.group(IppGroupTag.operation)!['printer-uri']!.first,
        'ipps://printer.local:8443/ipp',
      );

      client = IppClient(
        printerUri: Uri.parse('http://localhost:8631/ipp/print'),
        http: http,
      );
      await client.getPrinterAttributes();
      expect(
        http.requests.last.uri,
        Uri.parse('http://localhost:8631/ipp/print'),
      );
    });
  });

  group('every request', () {
    test('starts with the attributes printers insist on, in order', () async {
      await client.getPrinterAttributes();

      final operation = sent().message.group(IppGroupTag.operation)!;
      expect(operation.attributes.take(4).map((a) => a.name), [
        'attributes-charset',
        'attributes-natural-language',
        'printer-uri',
        'requesting-user-name',
      ]);
      expect(operation['requesting-user-name']!.first, 'PrinterHub');
      expect(sent().message.code, IppOperation.getPrinterAttributes);
    });

    test('has its own request id', () async {
      await client.getPrinterAttributes();
      await client.getPrinterAttributes();

      expect(sent().message.requestId, 1);
      expect(sent(1).message.requestId, 2);
    });
  });

  group('getPrinterAttributes', () {
    test('returns what the printer said about itself', () async {
      http.device = (_) => FakeAnswer.ipp(
        ippResponse(
          groups: [
            IppGroup(IppGroupTag.printer, [
              IppAttribute.single('printer-name', IppValueTag.name, 'Office'),
            ]),
          ],
        ),
      );

      final printer = await client.getPrinterAttributes(
        requested: ['printer-name'],
      );

      expect(printer.name, 'Office');
      expect(
        sent().message
            .group(IppGroupTag.operation)!['requested-attributes']!
            .strings,
        ['printer-name'],
      );
    });

    test('is empty when the printer sent no printer group', () async {
      expect((await client.getPrinterAttributes()).name, isNull);
    });
  });

  group('printing', () {
    const options = IppJobOptions(jobName: 'Report', copies: 2);

    test('validateJob asks without sending a document', () async {
      await client.validateJob(options);

      final decoded = sent();
      expect(decoded.message.code, IppOperation.validateJob);
      expect(decoded.message.group(IppGroupTag.job)!['copies']!.first, 2);
      expect(decoded.data, isEmpty);
      expect(
        http.requests.single.contentLength,
        http.requests.single.body.length,
      );
    });

    test('printJob sends the document after the attributes', () async {
      http.device = (_) =>
          FakeAnswer.ipp(ippResponse(groups: [jobGroup(id: 9)]));
      final document = Uint8List.fromList(List.generate(2000, (i) => i % 256));

      final job = await client.printJob(
        document: Stream.fromIterable([
          document.sublist(0, 700),
          document.sublist(700),
        ]),
        length: document.length,
        options: options,
      );

      final decoded = sent();
      final operation = decoded.message.group(IppGroupTag.operation)!;
      expect(job.id, 9);
      expect(job.state, IppJobState.pending);
      expect(decoded.message.code, IppOperation.printJob);
      expect(operation['job-name']!.first, 'Report');
      expect(operation['document-format']!.first, 'application/pdf');
      expect(decoded.data, document);
      expect(
        http.requests.single.contentLength,
        http.requests.single.body.length,
      );
    });

    test('printJob leaves the size open when it is not known', () async {
      await client.printJob(
        document: Stream.value([1, 2, 3]),
        options: const IppJobOptions(),
      );

      expect(http.requests.single.contentLength, isNull);
      expect(sent().message.group(IppGroupTag.job), isNull);
      expect(sent().message.group(IppGroupTag.operation)!['job-name'], isNull);
    });

    test('printJob tolerates an answer without a job', () async {
      final job = await client.printJob(
        document: const Stream.empty(),
        options: options,
      );

      expect(job.id, 0);
      expect(job.state, IppJobState.unknown);
    });

    test('getJobAttributes follows a job', () async {
      http.device = (_) =>
          FakeAnswer.ipp(ippResponse(groups: [jobGroup(state: 9)]));

      final job = await client.getJobAttributes(5);

      expect(job.state, IppJobState.completed);
      expect(sent().message.code, IppOperation.getJobAttributes);
      expect(sent().message.group(IppGroupTag.operation)!['job-id']!.first, 5);
    });

    test('getJobs lists the running jobs, or the finished ones', () async {
      http.device = (_) => FakeAnswer.ipp(
        ippResponse(groups: [jobGroup(id: 1), jobGroup(id: 2, state: 5)]),
      );

      final running = await client.getJobs();
      await client.getJobs(completed: true);

      expect(running.map((job) => job.id), [1, 2]);
      expect(
        sent().message.group(IppGroupTag.operation)!['which-jobs']!.first,
        'not-completed',
      );
      expect(
        sent(1).message.group(IppGroupTag.operation)!['which-jobs']!.first,
        'completed',
      );
    });

    test('cancelJob names the job', () async {
      await client.cancelJob(7);

      expect(sent().message.code, IppOperation.cancelJob);
      expect(sent().message.group(IppGroupTag.operation)!['job-id']!.first, 7);
    });
  });

  group('failures', () {
    test('a refusal inside HTTP 200 is an IppException', () async {
      http.device = (_) => FakeAnswer.ipp(
        ippResponse(
          status: IppStatus.clientErrorDocumentFormatNotSupported,
          statusMessage: 'Unsupported document format: text/plain',
        ),
      );

      await expectLater(
        client.validateJob(const IppJobOptions(documentFormat: 'text/plain')),
        throwsA(
          isA<IppException>()
              .having((e) => e.statusCode, 'statusCode', 0x040A)
              .having(
                (e) => e.statusName,
                'statusName',
                'client-error-document-format-not-supported',
              )
              .having((e) => e.message, 'message', contains('text/plain'))
              .having((e) => e.isClientError, 'isClientError', isTrue)
              .having((e) => '$e', 'toString', contains('document-format')),
        ),
      );
    });

    test("a printer fault is not the client's error", () async {
      http.device = (_) => FakeAnswer.ipp(
        ippResponse(status: IppStatus.serverErrorServiceUnavailable),
      );

      await expectLater(
        client.getPrinterAttributes(),
        throwsA(
          isA<IppException>()
              .having((e) => e.isClientError, 'isClientError', isFalse)
              .having((e) => e.message, 'message', isNull)
              .having(
                (e) => '$e',
                'toString',
                'IppException(server-error-service-unavailable)',
              ),
        ),
      );
    });

    test('an HTTP error means IPP is not available here', () async {
      for (final (status, needsAuth, needsTls) in [
        (404, false, false),
        (401, true, false),
        (426, false, true),
      ]) {
        http.device = (_) => FakeAnswer.text(status, 'no');

        await expectLater(
          client.getPrinterAttributes(),
          throwsA(
            isA<IppNotAvailable>()
                .having((e) => e.httpStatus, 'httpStatus', status)
                .having((e) => e.needsAuthentication, 'needsAuth', needsAuth)
                .having((e) => e.needsTls, 'needsTls', needsTls)
                .having((e) => '$e', 'toString', contains('HTTP $status')),
          ),
        );
      }
    });

    test('a web page at the address means IPP is not available here', () async {
      http.device = (_) => FakeAnswer.text(200, '<html>Printer home</html>');

      await expectLater(
        client.getPrinterAttributes(),
        throwsA(isA<IppNotAvailable>()),
      );
    });

    test('no answer at all passes through as unreachable', () async {
      final uri = Uri.parse('http://192.168.1.40:631/ipp/print');
      http.device = (_) => throw PrinterUnreachable(uri, 'timed out');

      await expectLater(
        client.getPrinterAttributes(),
        throwsA(
          isA<PrinterUnreachable>()
              .having((e) => e.uri, 'uri', uri)
              .having((e) => '$e', 'toString', contains('timed out')),
        ),
      );
    });
  });
}
