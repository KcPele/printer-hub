// Jobs and presets against the real API, with nothing faked: the local
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
import 'package:jobs_repository/jobs_repository.dart';
import 'package:local_store/local_store.dart';

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
  late PrinterHubClient client;
  late String org;
  late String printer;
  var running = false;

  setUpAll(() async {
    running = await _listening(8000);
    if (!running) return;
    // Widget tests block real network calls. These tests are about them.
    HttpOverrides.global = null;

    client = PrinterHubClient(
      baseUrl: Uri.parse(_api),
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
    org = (await client.api.organizations.createOrganization(
      body: const OrganizationCreate(name: 'Live workspace'),
    )).id;
    printer = (await client.api.printers.addPrinter(
      orgId: org,
      body: const PrinterCreate(friendlyName: 'Live printer'),
    )).id;
  });

  test('records a print, lists it, and tries a failed one again', () async {
    if (!running) return markTestSkipped('Run it with `make app-live-test`.');
    final jobs = JobsRepository(client: client, store: InMemorySecureStore());

    final started = await jobs.startPrint(
      organizationId: org,
      printerId: printer,
      title: 'Live.pdf',
      choices: const PrintChoices(copies: 2, sides: 'two_sided_long_edge'),
      pageCount: 3,
    );
    expect(started.waitingToSync, isFalse);
    expect(started.status, 'queued');
    expect(started.print!.copies, 2);

    for (final update in const [
      JobUpdate(status: 'processing'),
      JobUpdate(status: 'printing', printerJobRef: '7'),
      JobUpdate(
        status: 'failed',
        errorCode: 'print.connection_lost',
        errorMessage: 'The connection dropped.',
      ),
    ]) {
      await jobs.report(org, started.id, update);
    }

    final failed = await jobs.get(organizationId: org, jobId: started.id);
    expect(failed.status, 'failed');
    expect(failed.errorCode, 'print.connection_lost');
    expect(failed.canRetry, isTrue);
    expect(
      [
        for (final event in await jobs.events(
          organizationId: org,
          jobId: started.id,
        ))
          event.status,
      ],
      ['queued', 'processing', 'printing', 'failed'],
    );

    final again = await jobs.retry(organizationId: org, jobId: started.id);
    expect(again.retryOfJobId, started.id);
    expect(again.title, 'Live.pdf');
    expect(again.print, failed.print);

    final cancelled = await jobs.cancel(organizationId: org, jobId: again.id);
    expect(cancelled.status, 'cancelled');

    final problems = await jobs.list(
      organizationId: org,
      statuses: const ['failed', 'cancelled'],
    );
    expect(problems.jobs.map((job) => job.id), [again.id, started.id]);
    final done = await jobs.list(
      organizationId: org,
      statuses: const ['completed'],
    );
    expect(done.jobs, isEmpty);
  });

  test('sends a job that was started with the API out of reach', () async {
    if (!running) return markTestSkipped('Run it with `make app-live-test`.');
    final store = InMemorySecureStore();
    final nowhere = PrinterHubClient(
      baseUrl: Uri.parse('http://localhost:9'),
      tokenStore: InMemoryTokenStore(),
    );
    addTearDown(nowhere.close);
    final offline = JobsRepository(client: nowhere, store: store);

    final started = await offline.startPrint(
      organizationId: org,
      printerId: printer,
      title: 'Offline.pdf',
      choices: const PrintChoices(),
    );
    await offline.report(
      org,
      started.id,
      const JobUpdate(status: 'processing'),
    );
    await offline.report(
      org,
      started.id,
      const JobUpdate(status: 'completed', pageCount: 1),
    );
    expect(started.waitingToSync, isTrue);

    final online = JobsRepository(client: client, store: store);
    expect(await online.sync(org), 0);
    // Sent twice, it is still one job.
    expect(await online.sync(org), 0);

    final synced = await online.get(organizationId: org, jobId: started.id);
    expect(synced.status, 'completed');
    expect(synced.title, 'Offline.pdf');
  });

  test('saves, changes, and deletes a way of printing', () async {
    if (!running) return markTestSkipped('Run it with `make app-live-test`.');
    final presets = PresetsRepository(client: client);

    final saved = await presets.savePrint(
      organizationId: org,
      name: 'Handouts',
      choices: const PrintChoices(
        copies: 2,
        sides: 'two_sided_long_edge',
        pageRanges: '1-2',
      ),
      printerId: printer,
      isDefault: true,
    );
    expect(saved.isDefault, isTrue);
    expect(saved.shared, isFalse);
    expect(saved.printerId, printer);
    expect(saved.print!.copies, 2);
    expect(saved.print!.pageRanges, isNull);

    final shared = await presets.savePrint(
      organizationId: org,
      name: 'Everyone',
      choices: const PrintChoices(color: 'monochrome'),
      shared: true,
    );
    expect(shared.shared, isTrue);
    expect(shared.printerId, isNull);

    final renamed = await presets.update(
      organizationId: org,
      presetId: saved.id,
      name: 'Minutes',
    );
    expect(renamed.name, 'Minutes');
    expect(renamed.print, saved.print);
    expect(renamed.isDefault, isTrue);

    final replaced = await presets.update(
      organizationId: org,
      presetId: saved.id,
      choices: const PrintChoices(copies: 5),
      isDefault: false,
    );
    expect(replaced.print!.copies, 5);
    expect(replaced.print!.twoSided, isFalse);
    expect(replaced.isDefault, isFalse);
    expect(
      await presets.get(organizationId: org, presetId: saved.id),
      replaced,
    );

    final listed = await presets.list(organizationId: org, printerId: printer);
    expect(listed.map((preset) => preset.name), ['Everyone', 'Minutes']);
    expect(await presets.list(organizationId: org, kind: 'scan'), isEmpty);

    await presets.delete(organizationId: org, presetId: saved.id);
    await presets.delete(organizationId: org, presetId: shared.id);
    expect(await presets.list(organizationId: org), isEmpty);
  });
}
