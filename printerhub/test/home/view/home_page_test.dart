import 'package:api_client/testing.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/home/home.dart';
import 'package:printerhub/notifications/notifications.dart';
import 'package:printerhub/printers/printers.dart';
import 'package:printerhub/workspace/workspace.dart';

import '../../helpers/helpers.dart';

void main() {
  group('HomePage', () {
    late TestBackend backend;

    setUp(() => backend = TestBackend());
    tearDown(() => backend.close());

    /// Brings [target] onto the screen: the list builds only what is near it.
    Future<void> reveal(WidgetTester tester, Finder target) async {
      await tester.scrollUntilVisible(
        target,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    /// Reads what the workspace has switched on, as the app does at start.
    Future<void> loadFeatures(WidgetTester tester) async {
      await tester.runAsync(
        BlocProvider.of<FeaturesCubit>(tester.element(find.byType(HomePage)))
            .load,
      );
      await tester.pump();
    }

    testWidgets('tells a new user what the app is for and how to begin', (
      tester,
    ) async {
      await tester.pumpApp(const HomePage(), backend: backend);
      await tester.pumpAndSettle();

      expect(find.text('PrinterHub'), findsOneWidget);
      expect(find.byType(AppIllustration), findsOneWidget);
      expect(find.text('Find a printer, tap it, use it'), findsOneWidget);
      expect(find.byType(AppNotice), findsNothing);
      expect(
        find.widgetWithText(FilledButton, 'Add a printer'),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(find.text('Follow every job'), 200);
      expect(find.text('Getting started'), findsOneWidget);
      expect(find.text('Print or scan'), findsOneWidget);
      for (final number in ['1', '2', '3']) {
        expect(find.text(number), findsOneWidget);
      }
    });

    group('with no printer yet', () {
      late MockGoRouter router;

      setUp(() async {
        router = recordingRouter();
        await backend.signedInBefore();
      });

      Future<void> pump(WidgetTester tester) async {
        await tester.pumpApp(
          const HomePage(),
          backend: backend,
          router: router,
        );
        await tester.pumpAndSettle();
      }

      testWidgets('offers to add one, and to see which work', (tester) async {
        await pump(tester);

        await tester.tap(find.widgetWithText(FilledButton, 'Add a printer'));
        await tester.tap(find.text('See which printers work'));

        verify(() => router.go(AppRoutes.addPrinter)).called(1);
        verify(() => router.go(AppRoutes.catalogue)).called(1);
      });

      testWidgets('offers what the phone can do alone', (tester) async {
        backend.features = {'camera_scan': true};
        await pump(tester);
        await loadFeatures(tester);

        await reveal(tester, find.text('With your phone alone'));
        await reveal(tester, find.text('Your documents'));
        // Nothing to print on, and adding one is the button above.
        expect(find.text('Print a file'), findsNothing);
        expect(find.text('Nearby, by address, or by its code'), findsNothing);

        await tester.tap(find.text('Scan with your phone'));
        await tester.tap(find.text('Your documents'));

        verify(() => router.push<Object?>(AppRoutes.scan)).called(1);
        verify(() => router.go(AppRoutes.documents)).called(1);
      });

      testWidgets('offers no camera where the workspace has it switched off, '
          'or the phone has none', (tester) async {
        await pump(tester);
        await loadFeatures(tester);
        await reveal(tester, find.text('Your documents'));

        expect(find.text('Scan with your phone'), findsNothing);
      });

      testWidgets('offers no camera on a phone without one', (tester) async {
        backend
          ..features = {'camera_scan': true}
          ..camera.available = false;
        await pump(tester);
        await loadFeatures(tester);
        await reveal(tester, find.text('Your documents'));

        expect(find.text('Scan with your phone'), findsNothing);
      });
    });

    testWidgets('counts what has not been read, and opens it', (tester) async {
      final router = recordingRouter();
      backend.notificationList = [
        notificationBody(),
        notificationBody(id: 'notification-2'),
        notificationBody(id: 'notification-3', readAt: '2026-10-07T09:00:00Z'),
      ];
      await tester.runAsync(backend.signedInBefore);
      await tester.pumpApp(const HomePage(), backend: backend, router: router);
      await tester.pumpAndSettle();
      // Nothing is counted until the app asks.
      final count = find.descendant(
        of: find.byType(Badge),
        matching: find.text('2'),
      );
      expect(find.byType(Badge), findsOneWidget);
      expect(count, findsNothing);

      await tester.runAsync(
        BlocProvider.of<UnreadCubit>(tester.element(find.byType(HomePage)))
            .refresh,
      );
      await tester.pump();
      expect(count, findsOneWidget);

      await tester.tap(find.byTooltip('Notifications'));

      verify(() => router.push<Object?>(AppRoutes.notifications)).called(1);
    });

    testWidgets('reminds an unverified user to verify their email', (
      tester,
    ) async {
      final router = recordingRouter();
      await tester.runAsync(backend.signedInBefore);
      await tester.pumpApp(const HomePage(), backend: backend, router: router);
      await tester.pumpAndSettle();

      expect(find.byType(AppNotice), findsOneWidget);
      await tester.tap(find.text('Verify your email'));

      verify(() => router.push<Object?>(AppRoutes.verifyEmail)).called(1);
    });

    testWidgets('has no reminder for a verified user', (tester) async {
      backend.user = {
        ...backend.user,
        'email_verified_at': '2026-10-07T11:00:00Z',
      };
      await tester.runAsync(backend.signedInBefore);
      await tester.pumpApp(const HomePage(), backend: backend);
      await tester.pumpAndSettle();

      expect(find.byType(AppNotice), findsNothing);
    });

    group('with printers', () {
      late PrintersCubit printers;
      late MockGoRouter router;

      setUp(() async {
        backend.printerList = [
          for (var i = 1; i <= 4; i++)
            printerBody(id: 'printer-$i', name: 'Printer $i'),
        ];
        await backend.signedInBefore();
        router = recordingRouter();
        printers = PrintersCubit(
          printersRepository: backend.printers,
          organizationId: '0198c0de-0000-7000-8000-00000000000b',
          organizationChanges: const Stream.empty(),
        );
        await printers.load();
      });
      tearDown(() => printers.close());

      Future<void> pump(WidgetTester tester) async {
        await tester.pumpApp(
          const HomePage(),
          backend: backend,
          printersCubit: printers,
          router: router,
        );
        await tester.pumpAndSettle();
      }

      testWidgets('shows the first few in place of the introduction', (
        tester,
      ) async {
        await pump(tester);

        expect(find.text('Your printers'), findsOneWidget);
        expect(find.byType(PrinterCard), findsNWidgets(3));
        expect(find.text('Getting started'), findsNothing);
      });

      testWidgets('leads to a printer and to the whole list', (tester) async {
        await pump(tester);

        await tester.tap(find.text('See all'));
        await tester.ensureVisible(find.text('Printer 1'));
        await tester.tap(find.text('Printer 1'));

        verify(() => router.go(AppRoutes.printers)).called(1);
        verify(() => router.go(AppRoutes.printer('printer-1'))).called(1);
      });

      testWidgets('starts a print on a printer the person picks', (
        tester,
      ) async {
        await pump(tester);
        await reveal(tester, find.text('What would you like to do?'));
        await reveal(tester, find.text('Print a file'));
        expect(find.text('With your phone alone'), findsNothing);

        await tester.tap(find.text('Print a file'));
        await tester.pumpAndSettle();
        expect(find.text('Which printer?'), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text('Printer 2'),
          ),
        );
        await tester.pumpAndSettle();

        verify(() => router.go(AppRoutes.printOn('printer-2'))).called(1);
      });

      testWidgets('starts nothing when no printer is picked', (tester) async {
        await pump(tester);
        await reveal(tester, find.text('Print a file'));
        await tester.tap(find.text('Print a file'));
        await tester.pumpAndSettle();

        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();

        verifyNever(() => router.go(any(that: contains('/print'))));
      });

      testWidgets('opens the documents and adding another printer', (
        tester,
      ) async {
        await pump(tester);

        await reveal(tester, find.text('Add a printer'));
        await tester.tap(find.text('Your documents'));
        await tester.tap(find.text('Add a printer'));

        verify(() => router.go(AppRoutes.documents)).called(1);
        verify(() => router.go(AppRoutes.addPrinter)).called(1);
      });

      testWidgets('offers no printing when no printer prints', (tester) async {
        final scanner = printerBody();
        backend.printerList = [
          {
            ...scanner,
            'capabilities': {
              ...scanner['capabilities']! as Map<String, Object?>,
              'print': {
                ...(scanner['capabilities']! as Map<String, Object?>)['print']!
                    as Map<String, Object?>,
                'supported': false,
              },
            },
          },
        ];
        await tester.runAsync(printers.load);
        await pump(tester);
        await reveal(tester, find.text('Your documents'));

        expect(find.text('Print a file'), findsNothing);
      });
    });
  });
}
