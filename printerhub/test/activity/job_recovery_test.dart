import 'package:api_client/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:printerhub/activity/activity.dart';
import 'package:printers_repository/printers_repository.dart';

import '../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';

void main() {
  late TestBackend backend;
  late JobsRepository jobs;
  var now = DateTime.utc(2026, 10, 8, 10);

  setUp(() async {
    now = DateTime.utc(2026, 10, 8, 10);
    backend = TestBackend()
      ..printerList = [printerBody()]
      ..plugInPrinter();
    await backend.signedInBefore();
    // The app as it is after being closed and opened again: what it kept
    // is there, and nothing is running.
    jobs = JobsRepository(
      client: backend.client,
      store: backend.store,
      now: () => now,
    );
  });
  tearDown(() => backend.close());

  JobRecovery recovery() => JobRecovery(
    jobsRepository: jobs,
    printersRepository: backend.printers,
    now: () => now,
  );

  /// A print the app was closed during. With [onPrinter] the printer had
  /// taken it, as its job number 1; with [sent] the document reached the
  /// printer though the app never learned its number.
  Future<String> closedDuringPrint({
    bool onPrinter = true,
    bool sent = false,
  }) async {
    final before = JobsRepository(
      client: backend.client,
      store: backend.store,
      now: () => DateTime.utc(2026, 10, 8, 9),
    );
    final job = await before.startPrint(
      organizationId: _org,
      printerId: 'printer-1',
      title: 'Report.pdf',
      choices: const PrintChoices(),
    );
    await before.report(
      _org,
      job.id,
      onPrinter
          ? const JobUpdate(status: 'printing', printerJobRef: '1')
          : const JobUpdate(status: 'processing'),
    );
    if (sent) {
      // The printer has the document under the name it was sent with.
      final printer = PrinterRead.fromJson(printerBody().cast());
      final print = await backend.printers.print(
        organizationId: _org,
        printer: printer,
        document: PrintDocument(
          name: 'Report.pdf',
          mimeType: 'application/pdf',
          length: 4,
          open: () => Stream.value('%PDF'.codeUnits),
        ),
        request: const PrintRequest(),
        reference: job.id.substring(0, 8),
      );
      await print.progress.drain<void>();
    }
    return job.id;
  }

  Map<String, Object?> recorded(String id) =>
      backend.jobList.firstWhere((job) => job['id'] == id);

  group('a print the printer had taken', () {
    test('is done when the printer says it finished', () async {
      final id = await closedDuringPrint();

      await recovery().recover(_org);

      expect(recorded(id)['status'], 'completed');
      expect(await jobs.interrupted(_org), isEmpty);
      // The printer was only asked: nothing was sent to print.
      expect(backend.printed, isEmpty);
    });

    test('is cancelled when it was cancelled at the printer', () async {
      backend.printerJobState = 7;
      final id = await closedDuringPrint();

      await recovery().recover(_org);

      expect(recorded(id)['status'], 'cancelled');
    });

    test('is failed when the printer gave up on it', () async {
      backend.printerJobState = 8;
      final id = await closedDuringPrint();

      await recovery().recover(_org);

      expect(recorded(id)['status'], 'failed');
      expect(recorded(id)['error_code'], 'ipp.job-aborted');
    });

    test('is left alone while the printer is still at it', () async {
      backend.printerJobState = 5;
      final id = await closedDuringPrint();

      await recovery().recover(_org);

      expect(recorded(id)['status'], 'printing');
      expect(await jobs.interrupted(_org), hasLength(1));

      // It is settled the next time, once the printer is done.
      backend.printerJobState = 9;
      await recovery().recover(_org);
      expect(recorded(id)['status'], 'completed');
    });

    test('is unknown, not done, when the printer no longer knows it', () async {
      backend.printerForgetsJobs = true;
      final id = await closedDuringPrint();

      await recovery().recover(_org);

      expect(recorded(id)['status'], 'failed');
      expect(recorded(id)['error_code'], 'print.outcome_unknown');
      expect(await jobs.interrupted(_org), isEmpty);
    });
  });

  group('a print the app never learned the printer’s number for', () {
    test('never arrived, when the printer has nothing by its name', () async {
      final id = await closedDuringPrint(onPrinter: false);

      await recovery().recover(_org);

      expect(recorded(id)['status'], 'failed');
      expect(recorded(id)['error_code'], 'print.interrupted');
    });

    test('is found by its name when the document did arrive', () async {
      final id = await closedDuringPrint(onPrinter: false, sent: true);

      await recovery().recover(_org);

      expect(recorded(id)['status'], 'completed');
      // Found, not sent again.
      expect(backend.printed, hasLength(1));
    });
  });

  group('a printer that cannot be asked', () {
    test('is tried again later, for a day', () async {
      final id = await closedDuringPrint();
      backend.unplugPrinter();

      await recovery().recover(_org);
      expect(recorded(id)['status'], 'printing');
      expect(await jobs.interrupted(_org), hasLength(1));

      now = DateTime.utc(2026, 10, 9, 9, 30);
      await recovery().recover(_org);

      expect(recorded(id)['status'], 'failed');
      expect(recorded(id)['error_code'], 'print.outcome_unknown');
    });

    test('that never had the document is given up as never printed', () async {
      final id = await closedDuringPrint(onPrinter: false);
      backend.unplugPrinter();
      now = DateTime.utc(2026, 10, 10);

      await recovery().recover(_org);

      expect(recorded(id)['error_code'], 'print.interrupted');
    });

    test('that has left the workspace has nobody to ask', () async {
      final id = await closedDuringPrint();
      backend.printerList = [];

      await recovery().recover(_org);

      expect(recorded(id)['status'], 'failed');
      expect(recorded(id)['error_code'], 'print.outcome_unknown');
    });
  });

  test('waits when the API cannot be reached', () async {
    await closedDuringPrint();
    backend.offline = true;

    await recovery().recover(_org);

    expect(await jobs.interrupted(_org), hasLength(1));
  });

  test(
    'a scan the app was closed during is failed: its pages are gone',
    () async {
      final before = JobsRepository(
        client: backend.client,
        store: backend.store,
      );
      final scan = await before.startScan(
        organizationId: _org,
        printerId: 'printer-1',
        choices: const ScanChoices(),
      );

      await recovery().recover(_org);

      expect(recorded(scan.id)['status'], 'failed');
      expect(recorded(scan.id)['error_code'], 'scan.interrupted');
      expect(backend.device.requests, isEmpty);
    },
  );

  test('has nothing to do when nothing was interrupted', () async {
    await recovery().recover(_org);

    expect(backend.network.requests, isEmpty);
  });

  test('settles everything once, however often it is asked at once', () async {
    final id = await closedDuringPrint();
    final settling = recovery();

    await Future.wait([settling.recover(_org), settling.recover(_org)]);

    expect(
      backend.jobEvents[id]!.where((event) => event['status'] == 'completed'),
      hasLength(1),
    );
  });

  test(
    'a print that is running here is not taken for an interrupted one',
    () async {
      await jobs.startPrint(
        organizationId: _org,
        printerId: 'printer-1',
        title: 'Report.pdf',
        choices: const PrintChoices(),
      );

      await recovery().recover(_org);

      expect(backend.jobList.single['status'], 'queued');
      expect(backend.device.requests, isEmpty);
    },
  );
}
