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

    test('printJob asks first, then sends the document', () async {
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

      expect(http.requests, hasLength(2));
      expect(sent().message.code, IppOperation.validateJob);
      expect(sent().data, isEmpty);

      final decoded = sent(1);
      final operation = decoded.message.group(IppGroupTag.operation)!;
      expect(job.id, 9);
      expect(job.state, IppJobState.pending);
      expect(decoded.message.code, IppOperation.printJob);
      expect(operation['job-name']!.first, 'Report');
      expect(operation['document-format']!.first, 'application/pdf');
      expect(decoded.data, document);
      // The printer is always told the size up front.
      expect(http.requests[1].contentLength, http.requests[1].body.length);
    });

    test('printJob sends nothing when the printer would refuse', () async {
      http.device = (_) => FakeAnswer.ipp(
        ippResponse(status: IppStatus.clientErrorDocumentFormatNotSupported),
      );

      await expectLater(
        client.printJob(
          document: Stream.value([1, 2, 3]),
          length: 3,
          options: options,
        ),
        throwsA(isA<IppException>()),
      );
      expect(http.requests, hasLength(1));
    });

    test('printJob goes ahead on a printer too old to be asked', () async {
      http.device = (request) => FakeAnswer.ipp(
        decodeIpp(request.body).message.code == IppOperation.validateJob
            ? ippResponse(status: IppStatus.serverErrorOperationNotSupported)
            : ippResponse(groups: [jobGroup()]),
      );

      final job = await client.printJob(
        document: Stream.value([1, 2, 3]),
        length: 3,
        options: const IppJobOptions(),
      );

      expect(job.id, 5);
      expect(sent(1).message.group(IppGroupTag.job), isNull);
      expect(sent(1).message.group(IppGroupTag.operation)!['job-name'], isNull);
    });

    test('printJob sends at once when the caller has already asked', () async {
      await client.wouldAccept(options);
      await client.printJob(
        document: Stream.value([1, 2, 3]),
        length: 3,
        options: options,
        preflight: false,
      );

      expect(
        [for (var i = 0; i < http.requests.length; i++) sent(i).message.code],
        [IppOperation.validateJob, IppOperation.printJob],
      );
    });

    test('printJob tolerates an answer without a job', () async {
      final job = await client.printJob(
        document: const Stream.empty(),
        length: 0,
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

    test('falls back to IPP 1.1 for a printer that only speaks that', () async {
      http.device = (request) {
        final message = decodeIpp(request.body).message;
        return FakeAnswer.ipp(
          message.majorVersion == 2
              ? ippResponse(status: IppStatus.serverErrorVersionNotSupported)
              : ippResponse(),
        );
      };

      await client.getPrinterAttributes();
      await client.getJobs();

      expect(
        [
          for (var i = 0; i < 3; i++)
            '${sent(i).message.majorVersion}.${sent(i).message.minorVersion}',
        ],
        ['2.0', '1.1', '1.1'],
      );
    });

    test('a printer that speaks no version at all says so', () async {
      http.device = (_) => FakeAnswer.ipp(
        ippResponse(status: IppStatus.serverErrorVersionNotSupported),
      );

      await expectLater(
        client.getPrinterAttributes(),
        throwsA(
          isA<IppException>().having(
            (e) => e.statusCode,
            'statusCode',
            IppStatus.serverErrorVersionNotSupported,
          ),
        ),
      );
      expect(http.requests, hasLength(2));
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
  group('a printer that asks who is printing', () {
    const credentials = PrinterCredentials(userName: 'ada', password: 's3cret');
    const digest =
        'Digest realm="Xerox", nonce="abc123", qop="auth", opaque="xyz"';

    IppClient signedIn({bool secure = false}) => IppClient.forHost(
      '192.168.1.40',
      http: http,
      secure: secure,
      credentials: credentials,
    );

    /// Refuses requests without an `Authorization` header.
    void requireSignIn(String challenge, {bool Function(String)? accept}) {
      http.device = (request) {
        final given = request.headers['Authorization'];
        if (given == null || !(accept?.call(given) ?? true)) {
          return FakeAnswer(401, headers: {'www-authenticate': challenge});
        }
        return FakeAnswer.ipp(ippResponse(groups: [jobGroup()]));
      };
    }

    test('is told so when there is no password to give', () async {
      requireSignIn(digest);

      await expectLater(
        client.getPrinterAttributes(),
        throwsA(
          isA<IppNotAvailable>()
              .having((e) => e.needsAuthentication, 'needsAuth', isTrue)
              .having((e) => e.credentialsRefused, 'refused', isFalse)
              .having((e) => e.needsTls, 'needsTls', isFalse),
        ),
      );
      expect(http.requests, hasLength(1));
    });

    test('signs in with Digest, which never sends the password', () async {
      requireSignIn(digest);
      final printer = signedIn();

      await printer.getPrinterAttributes();
      await printer.getJobs();

      expect(http.requests, hasLength(3));
      final first = http.requests[1].headers['Authorization']!;
      final second = http.requests[2].headers['Authorization']!;
      expect(first, startsWith('Digest username="ada", realm="Xerox"'));
      expect(first, contains('uri="/ipp/print"'));
      expect(first, contains('nc=00000001'));
      expect(first, contains('opaque="xyz"'));
      expect(first, isNot(contains('s3cret')));
      // The same challenge serves the next request, counted up.
      expect(second, contains('nc=00000002'));
      expect(
        sent(1).message
            .group(IppGroupTag.operation)!['requesting-user-name']!
            .first,
        'ada',
      );
    });

    test('signs in before a document is sent, never during', () async {
      requireSignIn(digest);
      final printer = signedIn();

      final job = await printer.printJob(
        document: Stream.value([1, 2, 3]),
        length: 3,
        options: const IppJobOptions(),
      );

      expect(job.id, 5);
      expect(
        [for (var i = 0; i < 3; i++) sent(i).message.code],
        [
          IppOperation.validateJob,
          IppOperation.validateJob,
          IppOperation.printJob,
        ],
      );
      expect(http.requests[2].headers['Authorization'], contains('Digest'));
      expect(sent(2).data, [1, 2, 3]);
    });

    test('sends a Basic password only over a secure connection', () async {
      requireSignIn('Basic realm="Printer"');

      await signedIn(secure: true).getPrinterAttributes();
      expect(
        http.requests.last.headers['Authorization'],
        'Basic YWRhOnMzY3JldA==',
      );

      http.requests.clear();
      await expectLater(
        signedIn().getPrinterAttributes(),
        throwsA(
          isA<IppNotAvailable>()
              .having((e) => e.passwordNeedsTls, 'passwordNeedsTls', isTrue)
              .having((e) => e.needsTls, 'needsTls', isTrue),
        ),
      );
      expect(http.requests.single.headers, isNot(contains('Authorization')));
    });

    test('says when the password is wrong', () async {
      requireSignIn(digest, accept: (_) => false);

      await expectLater(
        signedIn().getPrinterAttributes(),
        throwsA(
          isA<IppNotAvailable>().having(
            (e) => e.credentialsRefused,
            'refused',
            isTrue,
          ),
        ),
      );
      expect(http.requests, hasLength(2));
    });

    test('signs again when the printer only wants a fresh signature', () async {
      var asked = 0;
      http.device = (request) {
        final given = request.headers['Authorization'];
        if (given != null && given.contains('nonce="fresh"')) {
          return FakeAnswer.ipp(ippResponse());
        }
        asked++;
        return FakeAnswer(
          401,
          headers: {
            'www-authenticate': given == null
                ? 'Digest realm="X", nonce="old"'
                : 'Digest realm="X", nonce="fresh", stale=true',
          },
        );
      };

      await signedIn().getPrinterAttributes();

      expect(asked, 2);
      expect(http.requests, hasLength(3));
    });

    test('cannot sign a document again once it has gone', () async {
      final printer = signedIn();
      requireSignIn('Digest realm="X", nonce="n"');
      await printer.getPrinterAttributes();

      // The printer forgets the session between the check and the document.
      var requests = 0;
      http.device = (request) {
        requests++;
        return requests == 1
            ? FakeAnswer.ipp(ippResponse())
            : const FakeAnswer(
                401,
                headers: {
                  'www-authenticate': 'Digest realm="X", nonce="m", stale=true',
                },
              );
      };

      await expectLater(
        printer.printJob(
          document: Stream.value([1]),
          length: 1,
          options: const IppJobOptions(),
        ),
        throwsA(
          isA<IppNotAvailable>().having(
            (e) => e.credentialsRefused,
            'refused',
            isFalse,
          ),
        ),
      );
    });

    test('is told so when the printer asks in a way the app cannot answer', () {
      requireSignIn('Negotiate');

      expect(
        signedIn().getPrinterAttributes(),
        throwsA(
          isA<IppNotAvailable>().having(
            (e) => e.needsAuthentication,
            'needsAuth',
            isTrue,
          ),
        ),
      );
    });
  });
}
