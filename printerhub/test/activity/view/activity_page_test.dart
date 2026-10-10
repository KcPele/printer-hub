import 'dart:io';

import 'package:api_client/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/activity/activity.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/printers/printers.dart';
import 'package:printerhub/session/session.dart';

import '../../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';

void main() {
  late TestBackend backend;
  late MockGoRouter router;
  late PrintersCubit printers;

  setUp(() async {
    backend = TestBackend()
      ..printerList = [printerBody()]
      ..jobList = [
        jobBody(id: 'job-3', status: 'printing', title: 'Now.pdf'),
        jobBody(
          id: 'job-2',
          status: 'failed',
          title: 'Broken.pdf',
          printerId: 'gone',
        ),
        jobBody(status: 'completed'),
      ];
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

  Future<void> pump(WidgetTester tester) async {
    await tester.runAsync(printers.load);
    await tester.pumpApp(
      const ActivityPage(),
      backend: backend,
      printersCubit: printers,
      router: router,
    );
    await tester.pumpAndSettle();
  }

  group('ActivityPage', () {
    testWidgets('shows what was made on the phone above the jobs', (
      tester,
    ) async {
      backend.documentList = [documentBody(name: 'Scan today.pdf')];
      await pump(tester);

      expect(find.text('Recent documents'), findsOneWidget);
      expect(find.text('Scan today.pdf'), findsOneWidget);
    });

    testWidgets('shows what was made on the phone when nothing has been '
        'printed or scanned on a printer', (tester) async {
      backend
        ..documentList = [documentBody(name: 'Scan today.pdf')]
        ..jobList = [];
      await pump(tester);

      expect(find.text('Scan today.pdf'), findsOneWidget);
      expect(find.text('Nothing here yet'), findsOneWidget);
    });

    testWidgets('shows what is on this phone when the history cannot be '
        'read for want of a network', (tester) async {
      await tester.runAsync(
        () => backend.library.add(
          organizationId: _org,
          file: File('${backend.scans.path}/Note.pdf')
            ..writeAsStringSync('%PDF made here'),
          mimeType: 'application/pdf',
        ),
      );
      backend.offline = true;
      await pump(tester);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Your activity could not be read'), findsOneWidget);
      expect(find.text('Recent documents'), findsOneWidget);
      expect(find.text('Note.pdf'), findsOneWidget);
      expect(find.text('Waiting to sync'), findsOneWidget);
    });

    testWidgets('says what will appear, before anything has', (tester) async {
      backend.jobList = [];

      await pump(tester);

      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('lists each job with its printer and how it went', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Now.pdf'), findsOneWidget);
      expect(find.text('Printing'), findsOneWidget);
      expect(find.text('Broken.pdf'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('Report.pdf'), findsOneWidget);
      expect(
        find.textContaining('Front desk · Wed, Oct 7 at '),
        findsNWidgets(2),
      );
      expect(
        find.textContaining('A printer that was removed · '),
        findsOneWidget,
      );
    });

    testWidgets('narrows to the jobs that went wrong', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Problems'));
      await tester.pumpAndSettle();

      expect(find.text('Broken.pdf'), findsOneWidget);
      expect(find.text('Now.pdf'), findsNothing);
    });

    testWidgets('says when nothing matches', (tester) async {
      backend.jobList = [jobBody()];
      await pump(tester);

      await tester.tap(find.text('Problems'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing like that here.'), findsOneWidget);
    });

    testWidgets('shows that it is reading after the filter changes', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Done'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('reads earlier jobs when asked', (tester) async {
      backend.jobPageSize = 2;
      await pump(tester);
      expect(find.text('Report.pdf'), findsNothing);

      await tester.tap(find.text('Show earlier'));
      await tester.pumpAndSettle();

      expect(find.text('Report.pdf'), findsOneWidget);
      expect(find.text('Show earlier'), findsNothing);
    });

    testWidgets('opens a job', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Now.pdf'));

      final job = verify(
        () => router.push<Object?>(
          AppRoutes.job('job-3'),
          extra: captureAny(named: 'extra'),
        ),
      ).captured.single;
      expect(job, isA<Job>().having((j) => j.id, 'id', 'job-3'));
    });

    testWidgets('opens the documents the workspace keeps', (tester) async {
      await pump(tester);

      await tester.tap(find.byTooltip('Documents'));

      verify(() => router.push<Object?>(AppRoutes.documents)).called(1);
    });

    testWidgets('reads again when pulled down', (tester) async {
      await pump(tester);
      backend.jobList = [
        jobBody(id: 'job-4', title: 'Later.pdf'),
        ...backend.jobList,
      ];

      await tester.drag(find.text('Now.pdf'), const Offset(0, 400));
      await tester.pumpAndSettle();

      expect(find.text('Later.pdf'), findsOneWidget);
    });

    testWidgets('says why the history cannot be read, and tries again', (
      tester,
    ) async {
      backend.offline = true;
      await pump(tester);

      expect(find.text('Your activity could not be read'), findsOneWidget);

      backend.offline = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Now.pdf'), findsOneWidget);
    });

    testWidgets('shows what is only on the phone while offline', (
      tester,
    ) async {
      backend.offline = true;
      await tester.runAsync(
        () => backend.jobs.startPrint(
          organizationId: _org,
          printerId: 'printer-1',
          title: 'Offline.pdf',
          choices: const PrintChoices(),
        ),
      );

      await pump(tester);

      expect(find.text('Offline.pdf'), findsOneWidget);
      expect(find.text('On this phone only'), findsOneWidget);
      expect(find.textContaining("Can't reach PrinterHub"), findsOneWidget);
    });

    testWidgets('is empty for the moment there is no workspace', (
      tester,
    ) async {
      final session = SessionCubit(
        authRepository: backend.auth,
        organizationsRepository: backend.organizations,
        preferencesRepository: emptyPreferences(),
      );
      addTearDown(session.close);

      await tester.pumpApp(
        const ActivityPage(),
        backend: backend,
        sessionCubit: session,
      );

      expect(find.byType(ActivityView), findsNothing);
    });
  });
}
