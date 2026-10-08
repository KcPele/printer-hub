import 'dart:convert';
import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:dio/dio.dart';
import 'package:documents_repository/documents_repository.dart';
import 'package:documents_repository/testing.dart';
import 'package:flutter_test/flutter_test.dart';

const _org = 'org-1';
const _documents = '/api/v1/organizations/$_org/documents';

void main() {
  late FakeApi api;
  late FakeFileTransfer storage;
  late Directory directory;
  late DocumentsRepository repository;
  late File scan;

  /// What the API says when a document is created: its upload, or none.
  Map<String, Object?>? uploadGiven;

  Map<String, dynamic> bodyOf(RequestOptions request) {
    return jsonDecode(jsonEncode(request.data)) as Map<String, dynamic>;
  }

  Map<String, Object?> instructions(String path) => {
    'url': 'https://storage.example.com$path?signature=abc',
    'method': 'PUT',
    'headers': {'Content-Type': 'application/pdf'},
    'expires_at': '2026-10-07T10:15:00Z',
  };

  setUp(() {
    uploadGiven = instructions('/first');
    storage = FakeFileTransfer();
    directory = Directory.systemTemp.createTempSync('documents_test');
    addTearDown(() => directory.deleteSync(recursive: true));
    scan = File('${directory.path}/scan.pdf')
      ..writeAsStringSync('%PDF-1.7 a scan');

    api = FakeApi((request) async {
      final path = request.path.replaceFirst(_documents, '');
      if (request.method == 'DELETE') return const FakeResponse(204);
      if (request.method == 'POST' && path.isEmpty) {
        final sent = bodyOf(request);
        return FakeResponse(201, {
          ...documentBody(
            id: sent['id'] as String,
            name: sent['file_name'] as String,
            sizeBytes: sent['size_bytes'] as int,
            uploadStatus: 'pending',
          ),
          'upload': uploadGiven,
        });
      }
      if (path.endsWith('/upload-url')) {
        return FakeResponse(200, instructions('/again'));
      }
      if (path.endsWith('/download-url')) {
        return const FakeResponse(200, {
          'url': 'https://storage.example.com/first?signature=down',
          'expires_at': '2026-10-07T10:15:00Z',
        });
      }
      if (request.method == 'GET' && path.isEmpty) {
        return FakeResponse(200, {
          'items': [
            documentBody(),
            documentBody(
              id: 'document-2',
              name: 'On the phone.jpg',
              mimeType: 'image/jpeg',
              storageMode: 'local',
              uploadStatus: 'not_applicable',
              pageCount: null,
              printerId: null,
              source: 'camera_scan',
            ),
          ],
          'next_cursor': 'next-page',
        });
      }
      return FakeResponse(
        200,
        documentBody(
          name: request.method == 'PATCH' ? 'Renamed.pdf' : 'Receipts.pdf',
        ),
      );
    });
    final client = PrinterHubClient(
      baseUrl: Uri.parse('https://api.example.com'),
      tokenStore: InMemoryTokenStore(),
      httpClientAdapter: api,
    );
    addTearDown(client.close);
    repository = DocumentsRepository(
      client: client,
      transfer: storage,
      directory: directory,
    );
  });

  Future<StoredDocument> keep() {
    return repository.keep(
      organizationId: _org,
      file: scan,
      name: 'Receipts.pdf',
      mimeType: 'application/pdf',
      pageCount: 3,
      printerId: 'printer-1',
    );
  }

  group('keep', () {
    test('makes the record, sends the file, and says it arrived', () async {
      final kept = await keep();

      final [create, complete] = api.requests;
      final sent = bodyOf(create);
      expect(create.path, _documents);
      expect(create.headers['Idempotency-Key'], hasLength(36));
      // An identifier that sorts by when it was made.
      expect(sent['id'], matches(RegExp('^[0-9a-f]{8}-[0-9a-f]{4}-7')));
      expect(sent['file_name'], 'Receipts.pdf');
      expect(sent['mime_type'], 'application/pdf');
      expect(sent['size_bytes'], scan.lengthSync());
      expect(sent['page_count'], 3);
      expect(sent['source'], 'printer_scan');
      expect(sent['storage_mode'], 'cloud');
      expect(sent['source_printer_id'], 'printer-1');
      expect(complete.path, '$_documents/${sent['id']}/complete-upload');

      // The file went where the API said, as the API said.
      final upload = storage.uploads.single;
      expect(upload.url.host, 'storage.example.com');
      expect(upload.url.queryParameters['signature'], 'abc');
      expect(upload.method, 'PUT');
      expect(upload.headers, {'Content-Type': 'application/pdf'});
      expect(utf8.decode(storage.stored['/first']!), '%PDF-1.7 a scan');

      expect(kept.name, 'Receipts.pdf');
      expect(kept.canFetch, isTrue);
      expect(kept.awaitsFile, isFalse);
    });

    test('says why the record cannot be made', () async {
      api.handler = (_) async =>
          FakeResponse.problem(403, 'document.cloud_storage_disabled');

      await expectLater(
        keep(),
        throwsA(
          isA<ApiProblem>().having(
            (e) => e.code,
            'code',
            'document.cloud_storage_disabled',
          ),
        ),
      );
      expect(storage.uploads, isEmpty);
    });

    test('hands back the record when the file does not arrive', () async {
      storage.broken = true;

      final interrupted = await keep().then<UploadInterrupted?>(
        (_) => null,
        onError: (Object error) => error as UploadInterrupted,
      );

      expect(interrupted!.document.awaitsFile, isTrue);
      expect(interrupted.cause, isA<TransferFailed>());
      expect('$interrupted', contains(interrupted.document.id));
    });

    test('asks for the upload when none came with the record', () async {
      uploadGiven = null;

      await keep();

      expect(api.requests[1].path, endsWith('/upload-url'));
      expect(storage.stored.keys, ['/again']);
    });
  });

  group('finish', () {
    test('sends the file of a document left without one', () async {
      storage.broken = true;
      late StoredDocument waiting;
      try {
        await keep();
      } on UploadInterrupted catch (interrupted) {
        waiting = interrupted.document;
      }
      storage.broken = false;
      api.requests.clear();

      final kept = await repository.finish(
        organizationId: _org,
        document: waiting,
        file: scan,
      );

      expect(api.requests.map((r) => r.path.split('/').last), [
        'upload-url',
        'complete-upload',
      ]);
      expect(storage.stored.keys, ['/again']);
      expect(kept.uploaded, isTrue);
    });

    test('says when it still cannot be sent', () async {
      api.handler = (_) async => throw const FormatException('offline');

      await expectLater(
        repository.finish(
          organizationId: _org,
          document: StoredDocument.fromApi(
            DocumentRead.fromJson(documentBody(uploadStatus: 'pending').cast()),
          ),
          file: scan,
        ),
        throwsA(
          isA<UploadInterrupted>().having(
            (e) => e.cause,
            'cause',
            isA<ApiUnreachable>(),
          ),
        ),
      );
    });
  });

  group('the list', () {
    test('is a page of documents, newest first', () async {
      final page = await repository.list(organizationId: _org);

      expect(api.requests.single.path, _documents);
      expect(api.requests.single.queryParameters, containsPair('limit', 50));
      expect(api.requests.single.queryParameters, isNot(contains('q')));
      expect(page.next, 'next-page');
      final [scanned, local] = page.documents;
      expect(scanned.name, 'Receipts.pdf');
      expect(scanned.pageCount, 3);
      expect(scanned.source, 'printer_scan');
      expect(scanned.printerId, 'printer-1');
      expect(scanned.sizeBytes, 2048);
      expect(scanned.createdAt, DateTime.utc(2026, 10, 7, 10));
      expect(scanned.canFetch, isTrue);
      // Only the phone that made it has this one's file.
      expect(local.inCloud, isFalse);
      expect(local.canFetch, isFalse);
      expect(local.awaitsFile, isFalse);
    });

    test('is searched, and read on', () async {
      await repository.list(
        organizationId: _org,
        query: ' receipts ',
        cursor: 'next-page',
      );

      final asked = api.requests.single.queryParameters;
      expect(asked['q'], 'receipts');
      expect(asked['cursor'], 'next-page');
    });

    test('is not searched for nothing', () async {
      await repository.list(organizationId: _org, query: '  ');

      expect(api.requests.single.queryParameters, isNot(contains('q')));
    });
  });

  test('reads one document', () async {
    final document = await repository.get(
      organizationId: _org,
      documentId: 'document-1',
    );

    expect(api.requests.single.path, '$_documents/document-1');
    expect(
      document,
      StoredDocument.fromApi(DocumentRead.fromJson(documentBody().cast())),
    );
  });

  test('renames a document', () async {
    final renamed = await repository.rename(
      organizationId: _org,
      documentId: 'document-1',
      name: 'Renamed.pdf',
    );

    expect(api.requests.single.method, 'PATCH');
    expect(bodyOf(api.requests.single)['file_name'], 'Renamed.pdf');
    expect(renamed.name, 'Renamed.pdf');
  });

  test('deletes a document', () async {
    await repository.delete(organizationId: _org, documentId: 'document-1');

    expect(api.requests.single.method, 'DELETE');
    expect(api.requests.single.path, '$_documents/document-1');
  });

  group('fetch', () {
    test('brings the file onto the phone, under its own name', () async {
      final kept = await keep();

      final file = await repository.fetch(organizationId: _org, document: kept);

      expect(file.path, '${directory.path}/${kept.id}/Receipts.pdf');
      expect(file.readAsStringSync(), '%PDF-1.7 a scan');
      expect(api.requests.last.path, endsWith('/download-url'));
    });

    test('gives a name with a slash in it a place of its own', () async {
      storage.stored['/first'] = [1, 2, 3];
      final odd = StoredDocument(
        id: 'document-9',
        name: 'a/b.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 3,
        createdAt: DateTime.utc(2026),
        inCloud: true,
        uploaded: true,
      );

      final file = await repository.fetch(organizationId: _org, document: odd);

      expect(file.path, endsWith('/document-9/a-b.pdf'));
    });

    test('says when the file cannot be fetched', () async {
      final kept = await keep();
      storage.broken = true;

      await expectLater(
        repository.fetch(organizationId: _org, document: kept),
        throwsA(isA<TransferFailed>()),
      );
    });
  });

  test('keeps fetched files with the system’s temporary ones unless told '
      'where', () async {
    final client = PrinterHubClient(
      baseUrl: Uri.parse('https://api.example.com'),
      tokenStore: InMemoryTokenStore(),
      httpClientAdapter: api,
    );
    addTearDown(client.close);
    storage.stored['/first'] = [1];
    final document = StoredDocument.fromApi(
      DocumentRead.fromJson(documentBody(id: 'documents-test-tmp').cast()),
    );

    final file = await DocumentsRepository(
      client: client,
      transfer: storage,
    ).fetch(organizationId: _org, document: document);

    addTearDown(() => file.parent.deleteSync(recursive: true));
    expect(file.path, startsWith(Directory.systemTemp.path));
  });
}
