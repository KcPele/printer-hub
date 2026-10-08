// Notifications against the real API, with nothing faked: the local
// backend (`make dev`).
//
//   make app-live-test
//
// Skipped when it is not running. It registers a throwaway account on the
// backend and deletes it at the end.
@Tags(['live'])
library;

import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications_repository/notifications_repository.dart';

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
  test('is told when a job fails, and reads it', () async {
    if (!await _listening(8000)) {
      markTestSkipped('Run it with `make app-live-test`.');
      return;
    }
    // Widget tests block real network calls. This test is about them.
    HttpOverrides.global = null;

    final client = PrinterHubClient(
      baseUrl: Uri.parse('http://localhost:8000'),
      tokenStore: InMemoryTokenStore(),
    );
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
      await client.close();
    });
    final org = (await client.api.organizations.createOrganization(
      body: const OrganizationCreate(name: 'Live workspace'),
    )).id;
    final printer = (await client.api.printers.addPrinter(
      orgId: org,
      body: const PrinterCreate(friendlyName: 'Live printer'),
    )).id;
    final repository = NotificationsRepository(client: client);
    expect(await repository.unreadCount(), 0);

    // A job that fails is something its owner is told about.
    final job = await client.api.jobs.createJob(
      orgId: org,
      idempotencyKey: newIdempotencyKey(),
      body: JobCreatePrintJobCreate(
        id: newRecordId(),
        type: 'print',
        printerId: printer,
        executionMode: ExecutionMode.local,
        title: 'Live.pdf',
        documentId: null,
        connectionId: null,
        pageCount: 1,
        submittedAt: DateTime.now().toUtc(),
        settings: const PrintSettingsInput(),
      ),
    );
    await client.api.jobs.reportJobEvent(
      orgId: org,
      jobId: job.toJson()['id']! as String,
      body: const JobEventCreate(
        status: JobStatus.failed,
        errorCode: 'print.unreachable',
      ),
    );

    expect(await repository.unreadCount(), 1);
    final told = (await repository.list(unreadOnly: true)).notifications.single;
    expect(told.type, 'job.failed');
    expect(told.jobId, job.toJson()['id']);
    expect(told.organizationId, org);
    expect(told.isRead, isFalse);

    final read = await repository.markRead(told.id);
    expect(read.isRead, isTrue);
    expect(await repository.unreadCount(), 0);
    expect((await repository.list(unreadOnly: true)).notifications, isEmpty);
    expect((await repository.list()).notifications.single.id, told.id);

    await repository.markAllRead();
    expect(await repository.unreadCount(), 0);
  });
}
