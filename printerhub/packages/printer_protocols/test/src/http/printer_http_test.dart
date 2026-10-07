import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:printer_protocols/printer_protocols.dart';
import 'package:test/test.dart';

void main() {
  group('IoPrinterHttp', () {
    late HttpServer server;
    late IoPrinterHttp http;
    late Uri base;

    Future<void> serve(
      Future<void> Function(HttpRequest request) handler,
    ) async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      base = Uri.parse('http://127.0.0.1:${server.port}');
      server.listen(handler);
    }

    setUp(() => http = IoPrinterHttp());
    tearDown(() async {
      http.close();
      await server.close(force: true);
    });

    test('sends a request and reads the answer', () async {
      late String method;
      late String sentHeader;
      late String sentBody;
      await serve((request) async {
        method = request.method;
        sentHeader = request.headers.value('content-type')!;
        sentBody = await utf8.decodeStream(request);
        request.response
          ..statusCode = 201
          ..headers.set('Location', '/eSCL/ScanJobs/1')
          ..write('created');
        await request.response.close();
      });

      final response = await http.send(
        'POST',
        base.replace(path: '/eSCL/ScanJobs'),
        headers: const {'Content-Type': 'text/xml'},
        body: Stream.fromIterable([utf8.encode('<a>'), utf8.encode('</a>')]),
        contentLength: 7,
      );

      expect(method, 'POST');
      expect(sentHeader, 'text/xml');
      expect(sentBody, '<a></a>');
      expect(response.statusCode, 201);
      expect(response.headers['location'], '/eSCL/ScanJobs/1');
      expect(utf8.decode(await response.bytes()), 'created');
    });

    test('sends a request without a body', () async {
      await serve((request) async {
        request.response.write(request.method);
        await request.response.close();
      });

      final response = await http.send('GET', base);

      expect(utf8.decode(await response.bytes()), 'GET');
    });

    test('says a device that refuses the connection is unreachable', () async {
      await serve((_) async {});
      final port = server.port;
      await server.close(force: true);

      await expectLater(
        http.send('GET', Uri.parse('http://127.0.0.1:$port')),
        throwsA(
          isA<PrinterUnreachable>().having(
            (e) => e.cause,
            'cause',
            isA<IOException>(),
          ),
        ),
      );
    });

    test('says a device that never answers is unreachable', () async {
      final hang = Completer<void>();
      await serve((_) => hang.future);
      final impatient = IoPrinterHttp(
        responseTimeout: const Duration(milliseconds: 100),
      );
      addTearDown(impatient.close);

      await expectLater(
        impatient.send('GET', base),
        throwsA(
          isA<PrinterUnreachable>().having(
            (e) => e.cause,
            'cause',
            isA<TimeoutException>(),
          ),
        ),
      );
      hang.complete();
    });
  });

  group('IoPrinterHttp with a self-signed device', () {
    late HttpServer server;
    late Uri base;

    setUp(() async {
      // A certificate made only for this test, like the one every printer
      // signs for itself.
      final context = SecurityContext()
        ..useCertificateChain('test/fixtures/test_only_cert.pem')
        ..usePrivateKey('test/fixtures/test_only_key.pem');
      server = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        context,
      );
      base = Uri.parse('https://127.0.0.1:${server.port}');
      server.listen((request) async {
        request.response.write('secure');
        await request.response.close();
      });
    });
    tearDown(() => server.close(force: true));

    test('is refused by default', () async {
      final http = IoPrinterHttp();
      addTearDown(http.close);

      await expectLater(
        http.send('GET', base),
        throwsA(isA<PrinterUnreachable>()),
      );
    });

    test('is reached when its certificate is accepted', () async {
      final seen = <(String, int, String)>[];
      final http = IoPrinterHttp(
        certificateCheck: (host, port, fingerprint) {
          seen.add((host, port, fingerprint));
          return true;
        },
      );
      addTearDown(http.close);

      final response = await http.send('GET', base);

      expect(utf8.decode(await response.bytes()), 'secure');
      expect(seen.single.$1, '127.0.0.1');
      expect(seen.single.$2, server.port);
      expect(seen.single.$3, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('is refused when its certificate is not the one remembered', () async {
      final http = IoPrinterHttp(certificateCheck: (_, _, _) => false);
      addTearDown(http.close);

      await expectLater(
        http.send('GET', base),
        throwsA(isA<PrinterUnreachable>()),
      );
    });
  });

  test('a fingerprint is the SHA-256 of the certificate', () {
    expect(
      IoPrinterHttp.fingerprintOf(utf8.encode('abc')),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });
}
