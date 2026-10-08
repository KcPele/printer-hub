import 'dart:convert';
import 'dart:io';

import 'package:documents_repository/documents_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  late Directory directory;
  late IoFileTransfer transfer;

  /// What the server was last sent.
  late String method;
  late Map<String, String> headers;
  late List<int> received;

  /// What it answers with.
  var status = 200;
  var body = 'the file';
  var hangUp = false;

  Uri at(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');

  setUp(() async {
    // Widget tests block real network calls. These tests are about them.
    HttpOverrides.global = null;
    status = 200;
    body = 'the file';
    hangUp = false;
    directory = Directory.systemTemp.createTempSync('file_transfer_test');
    Future<void> answer(HttpRequest request) async {
      method = request.method;
      headers = {};
      request.headers.forEach((name, values) => headers[name] = values.first);
      received = await request.fold<List<int>>([], (all, chunk) => all + chunk);
      if (hangUp) {
        // Says a body is coming, then goes away part of the way through.
        final socket = await request.response.detachSocket(writeHeaders: false);
        socket.write('HTTP/1.1 200 OK\r\nContent-Length: 1000\r\n\r\nhalf');
        await socket.flush();
        socket.destroy();
        return;
      }
      request.response
        ..statusCode = status
        ..write(body);
      await request.response.close();
    }

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
      ..listen(answer);
    transfer = IoFileTransfer();
    addTearDown(() async {
      transfer.close();
      await server.close(force: true);
      directory.deleteSync(recursive: true);
    });
  });

  group('upload', () {
    test('sends the file as it is, with the headers it was given', () async {
      final file = File('${directory.path}/scan.pdf')
        ..writeAsStringSync('%PDF-1.7 a scan');

      await transfer.upload(
        at('/bucket/key?signature=abc'),
        file: file,
        headers: {'Content-Type': 'application/pdf', 'x-amz-meta-a': 'b'},
      );

      expect(method, 'PUT');
      expect(utf8.decode(received), '%PDF-1.7 a scan');
      expect(headers['content-type'], 'application/pdf');
      expect(headers['x-amz-meta-a'], 'b');
      expect(headers['content-length'], '${file.lengthSync()}');
      // Nothing of the account goes with it.
      expect(headers, isNot(contains('authorization')));
    });

    test('uses the method it is told to', () async {
      final file = File('${directory.path}/scan.pdf')..writeAsStringSync('x');

      await transfer.upload(at('/form'), file: file, method: 'POST');

      expect(method, 'POST');
    });

    test('says when the storage refuses the file', () async {
      status = 403;
      final file = File('${directory.path}/scan.pdf')..writeAsStringSync('x');

      await expectLater(
        transfer.upload(at('/expired'), file: file),
        throwsA(
          isA<TransferFailed>()
              .having((e) => e.statusCode, 'status', 403)
              .having((e) => '$e', 'words', contains('HTTP 403')),
        ),
      );
    });

    test('says when the storage cannot be reached', () async {
      final file = File('${directory.path}/scan.pdf')..writeAsStringSync('x');

      await expectLater(
        transfer.upload(Uri.parse('http://127.0.0.1:9/nowhere'), file: file),
        throwsA(
          isA<TransferFailed>()
              .having((e) => e.statusCode, 'status', isNull)
              .having((e) => '$e', 'words', isNot(contains('HTTP'))),
        ),
      );
    });
  });

  group('download', () {
    test('writes what the storage gives to the file', () async {
      final into = File('${directory.path}/fetched.pdf');

      await transfer.download(at('/bucket/key'), into: into);

      expect(method, 'GET');
      expect(into.readAsStringSync(), 'the file');
    });

    test('says when the storage has nothing there', () async {
      status = 404;
      final into = File('${directory.path}/fetched.pdf');

      await expectLater(
        transfer.download(at('/gone'), into: into),
        throwsA(
          isA<TransferFailed>().having((e) => e.statusCode, 'status', 404),
        ),
      );
      expect(into.existsSync(), isFalse);
    });

    test('leaves no half a file when the connection drops', () async {
      hangUp = true;
      final into = File('${directory.path}/fetched.pdf');

      await expectLater(
        transfer.download(at('/bucket/key'), into: into),
        throwsA(isA<TransferFailed>()),
      );
      expect(into.existsSync(), isFalse);
    });

    test('says when the storage cannot be reached', () async {
      final into = File('${directory.path}/fetched.pdf');

      await expectLater(
        transfer.download(Uri.parse('http://127.0.0.1:9/nowhere'), into: into),
        throwsA(isA<TransferFailed>()),
      );
    });
  });
}
