// Documents against the real API and its storage, with nothing faked: the
// local backend (`make dev`) and MinIO (`make infra`).
//
//   make app-live-test
//
// Skipped when the backend is not running. It registers a throwaway
// account on the backend and deletes it at the end.
@Tags(['live'])
library;

import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:documents_repository/documents_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _api = 'http://localhost:8000';

Future<bool> _listening(int port) async {
  // Asked for by name: these tests make accounts on whatever is listening.
  if (Platform.environment['PRINTERHUB_LIVE'] != '1') return false;
  try {
    final socket = await Socket.connect(
      'localhost',
      port,
      timeout: const Duration(seconds: 1),
    );
    socket.destroy();
    return true;
  } on Object {
    return false;
  }
}

void main() {
  test('keeps a scan in the workspace, and fetches it back', () async {
    if (!await _listening(8000) || !await _listening(9000)) {
      markTestSkipped('Run it with `make app-live-test`.');
      return;
    }
    // Widget tests block real network calls. This test is about them.
    HttpOverrides.global = null;

    final client = PrinterHubClient(
      baseUrl: Uri.parse(_api),
      tokenStore: InMemoryTokenStore(),
    );
    final transfer = IoFileTransfer();
    final directory = Directory.systemTemp.createTempSync('documents_live');
    final password = 'live-${newIdempotencyKey()}';
    final registered = await client.api.auth.register(
      body: RegisterRequest(
        name: 'Live Test',
        email: 'live-${DateTime.now().microsecondsSinceEpoch}@example.com',
        password: password,
      ),
    );
    await client.startSession(registered.tokens);
    addTearDown(() async {
      await client.api.account.deleteAccount(
        body: AccountDeleteRequest(password: password),
      );
      transfer.close();
      await client.close();
      directory.deleteSync(recursive: true);
    });
    final org = (await client.api.organizations.createOrganization(
      body: const OrganizationCreate(name: 'Live workspace'),
    )).id;
    final repository = DocumentsRepository(
      client: client,
      transfer: transfer,
      directory: directory,
    );
    final scan = File('${directory.path}/scan.pdf')
      ..writeAsStringSync('%PDF-1.7 ${'a scanned page ' * 200}');

    final kept = await repository.keep(
      organizationId: org,
      file: scan,
      name: 'Receipts.pdf',
      mimeType: 'application/pdf',
      pageCount: 2,
    );
    expect(kept.canFetch, isTrue);
    expect(kept.sizeBytes, scan.lengthSync());
    expect(kept.source, 'printer_scan');

    final second = await repository.keep(
      organizationId: org,
      file: scan,
      name: 'Contract.pdf',
      mimeType: 'application/pdf',
    );
    // Newest first, by identifiers the phone made.
    final listed = await repository.list(organizationId: org);
    expect(listed.documents.map((d) => d.name), [
      'Contract.pdf',
      'Receipts.pdf',
    ]);
    final found = await repository.list(organizationId: org, query: 'receipt');
    expect(found.documents.single.id, kept.id);

    final renamed = await repository.rename(
      organizationId: org,
      documentId: kept.id,
      name: 'Receipts October.pdf',
    );
    expect(renamed.name, 'Receipts October.pdf');
    expect(
      await repository.get(organizationId: org, documentId: kept.id),
      renamed,
    );

    final fetched = await repository.fetch(
      organizationId: org,
      document: renamed,
    );
    expect(fetched.path, endsWith('/Receipts October.pdf'));
    expect(fetched.readAsBytesSync(), scan.readAsBytesSync());

    await repository.delete(organizationId: org, documentId: kept.id);
    await repository.delete(organizationId: org, documentId: second.id);
    expect((await repository.list(organizationId: org)).documents, isEmpty);
  });
}
