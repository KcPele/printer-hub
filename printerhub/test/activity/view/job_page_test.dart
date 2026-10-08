import 'package:api_client/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/activity/activity.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/printers/printers.dart';

import '../../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';

void main() {
  late TestBackend backend;
  late MockGoRouter router;
  late PrintersCubit printers;

  setUp(() async {
    backend = TestBackend()..printerList = [printerBody()];
    router = recordingRouter();
    await backend.signedInBefore();
    printers = PrintersCubit(
      printersRepository: backend.printers,
      organizationId: _org,
      organizationChanges: const Stream.empty(),
    );
  });
  tearDown(() async {
    await printers.close();
    await backend.close();
  });

  /// Puts one job on the backend's record, with what happened to it.
  void record(
    Map<String, Object?> job, {
    List<Map<String, dynamic>> events = const [],
  }) {
    backend
      ..jobList = [job]
      ..jobEvents[job['id']! as String] = [...events];
  }

  Future<void> pump(
    WidgetTester tester, {
    String jobId = 'job-1',
    Job? known,
  }) async {
    await tester.runAsync(printers.load);
    await tester.pumpApp(
      JobPage(jobId: jobId, known: known),
      backend: backend,
      printersCubit: printers,
      router: router,
    );
    await tester.pumpAndSettle();
  }

  group('JobPage', () {
    testWidgets('says what was asked for and what happened', (tester) async {
      record(
        jobBody(status: 'completed', copies: 2, pageCount: 3),
        events: [
          {'status': 'processing', 'connection_id': 'connection-ipp-1'},
          {'status': 'printing', 'connection_id': 'connection-ipp-1'},
          {'status': 'completed', 'connection_id': 'connection-ipp-1'},
        ],
      );

      await pump(tester);

      expect(find.widgetWithText(AppBar, 'Print'), findsOneWidget);
      expect(find.text('Report.pdf'), findsOneWidget);
      expect(find.text('Front desk'), findsOneWidget);
      expect(find.text('3 pages'), findsOneWidget);
      expect(find.text('2 copies'), findsOneWidget);
      expect(find.text('One side'), findsOneWidget);
      expect(find.text('What happened'), findsOneWidget);
      expect(find.text('Getting ready'), findsOneWidget);
      expect(find.text('Printing'), findsOneWidget);
      // Where it stands, and the last thing that happened.
      expect(find.text('Done'), findsNWidgets(2));
    });

    testWidgets('lists every choice that was made', (tester) async {
      final job = jobBody(status: 'completed');
      final settings = job['settings']! as Map<String, Object?>;
      record({
        ...job,
        'settings': {
          ...settings,
          'color_mode': 'monochrome',
          'duplex': 'two_sided_long_edge',
          'media_size': 'iso_a4_210x297mm',
          'tray': 'tray-2',
          'quality': 'high',
        },
      });

      await pump(tester);

      expect(find.text('1 copy'), findsOneWidget);
      expect(find.text('Black and white'), findsOneWidget);
      expect(find.text('A4'), findsOneWidget);
      expect(find.text('Tray 2'), findsOneWidget);
      expect(find.text('Best'), findsOneWidget);
      expect(find.text('Both sides'), findsOneWidget);
    });

    testWidgets('says when colour was asked for', (tester) async {
      final job = jobBody(status: 'completed');
      record({
        ...job,
        'settings': {
          ...job['settings']! as Map<String, Object?>,
          'color_mode': 'color',
        },
      });

      await pump(tester);

      expect(find.text('In colour'), findsOneWidget);
    });

    testWidgets('says why a job failed, and at which step', (tester) async {
      record(
        jobBody(
          status: 'failed',
          errorCode: 'print.unreachable',
          fallbackOccurred: true,
          retryOf: 'job-0',
        ),
        events: [
          {'status': 'processing', 'connection_id': 'connection-ipp-1'},
          {
            'status': 'failed',
            'connection_id': 'connection-ipp-1',
            'error_code': 'print.unreachable',
          },
        ],
      );

      await pump(tester);

      expect(find.textContaining('The printer did not answer'), findsOneWidget);
      expect(find.textContaining('another was used'), findsOneWidget);
      expect(find.textContaining('another try'), findsOneWidget);

      // The step it failed on says why too.
      final step = find.textContaining('Failed\nThe printer did not answer');
      await tester.scrollUntilVisible(step, 200);
      expect(step, findsOneWidget);
    });

    testWidgets('offers to print a failed job again, as another try', (
      tester,
    ) async {
      record(jobBody(status: 'failed', errorCode: 'print.unreachable'));
      await pump(tester);

      await tester.scrollUntilVisible(find.text('Print it again'), 200);
      await tester.tap(find.text('Print it again'));

      final job = verify(
        () => router.go(
          AppRoutes.printOn('printer-1'),
          extra: captureAny(named: 'extra'),
        ),
      ).captured.single;
      expect(job, isA<Job>().having((j) => j.id, 'id', 'job-1'));
    });

    testWidgets('offers to print a finished job again, as a new one', (
      tester,
    ) async {
      record(jobBody(status: 'completed'));
      await pump(tester);

      await tester.tap(find.text('Print it again'));

      verify(() => router.go(AppRoutes.printOn('printer-1'))).called(1);
    });

    testWidgets('does not offer to print on a printer that has gone', (
      tester,
    ) async {
      record(jobBody(status: 'completed', printerId: 'gone'));

      await pump(tester);

      expect(find.text('A printer that was removed'), findsOneWidget);
      expect(find.text('Print it again'), findsNothing);
    });

    testWidgets('marks a job that will not finish as cancelled', (
      tester,
    ) async {
      record(jobBody(status: 'printing'));
      await pump(tester);
      expect(find.text('Print it again'), findsNothing);

      await tester.tap(find.text('Mark as cancelled'));
      await tester.pumpAndSettle();

      expect(find.text('Marked as cancelled'), findsOneWidget);
      expect(find.text('Mark as cancelled'), findsNothing);
      expect(backend.jobList.single['status'], 'cancelled');
    });

    testWidgets('says why a job could not be marked cancelled', (tester) async {
      record(jobBody(status: 'printing'));
      await pump(tester);
      backend.fail(
        'POST /organizations/$_org/jobs/job-1/cancel',
        403,
        'permission.denied',
        detail: 'You may not change this job.',
      );

      await tester.tap(find.text('Mark as cancelled'));
      await tester.pumpAndSettle();

      expect(find.text('Mark as cancelled'), findsOneWidget);
      expect(find.text('You may not change this job.'), findsOneWidget);
    });

    testWidgets('shows what the list knew while the rest is read', (
      tester,
    ) async {
      record(jobBody(status: 'printing'));
      final known = Job.fromJson(jobBody(status: 'printing').cast());

      await tester.runAsync(printers.load);
      await tester.pumpApp(
        JobPage(jobId: 'job-1', known: known),
        backend: backend,
        printersCubit: printers,
        router: router,
      );

      expect(find.text('Report.pdf'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('keeps what the list knew when the rest cannot be read', (
      tester,
    ) async {
      record(jobBody(status: 'printing'));
      final known = Job.fromJson(jobBody(status: 'printing').cast());
      backend.offline = true;
      await tester.pumpApp(
        JobPage(jobId: 'job-1', known: known),
        backend: backend,
        printersCubit: printers,
        router: router,
      );
      await tester.pumpAndSettle();

      expect(find.text('Report.pdf'), findsOneWidget);
      expect(find.textContaining("Can't reach PrinterHub"), findsOneWidget);

      backend.offline = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.textContaining("Can't reach PrinterHub"), findsNothing);
    });

    testWidgets('says a job is only on the phone, and asks nothing', (
      tester,
    ) async {
      final known = Job.fromJson(
        jobBody(type: 'scan', title: null).cast(),
        waitingToSync: true,
      );

      await pump(tester, known: known);

      expect(find.widgetWithText(AppBar, 'Scan'), findsOneWidget);
      expect(find.text('A scan'), findsOneWidget);
      expect(find.textContaining('only on your phone'), findsOneWidget);
      expect(find.text('Mark as cancelled'), findsNothing);
      expect(find.text('What was asked for'), findsNothing);
    });

    testWidgets('says why a job cannot be read, and tries again', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('This job could not be read'), findsOneWidget);

      record(jobBody());
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.text('Report.pdf'), findsOneWidget);
    });
  });
}
