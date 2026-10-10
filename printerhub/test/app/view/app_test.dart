import 'package:api_client/testing.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/account/account.dart';
import 'package:printerhub/activity/activity.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/auth/auth.dart';
import 'package:printerhub/catalogue/catalogue.dart';
import 'package:printerhub/copy/copy.dart';
import 'package:printerhub/documents/documents.dart';
import 'package:printerhub/gallery/gallery.dart';
import 'package:printerhub/home/home.dart';
import 'package:printerhub/notifications/notifications.dart';
import 'package:printerhub/print/print.dart';
import 'package:printerhub/printers/printers.dart';
import 'package:printerhub/scan/scan.dart';
import 'package:printerhub/session/session.dart';
import 'package:printerhub/settings/settings.dart';
import 'package:printerhub/theme/theme.dart';
import 'package:printerhub/tools/tools.dart';
import 'package:printerhub/welcome/welcome.dart';
import 'package:printerhub/workspace/workspace.dart';

import '../../helpers/helpers.dart';

void main() {
  group('App', () {
    late TestBackend backend;

    setUp(() => backend = TestBackend());
    tearDown(() => backend.close());

    AppColors? coloursOf(WidgetTester tester, Type screen) {
      return Theme.of(tester.element(find.byType(screen)))
          .extension<AppColors>();
    }

    Future<MockPreferencesRepository> pump(
      WidgetTester tester, {
      String? themeName,
      bool welcomed = true,
    }) async {
      final preferences = emptyPreferences(
        themeName: themeName,
        onboardingCompleted: welcomed,
      );
      await tester.pumpWholeApp(backend, preferences);
      return preferences;
    }

    Future<void> openArea(WidgetTester tester, String label) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('is named PrinterHub', (tester) async {
      await pump(tester);

      expect(
        tester.widget<Title>(find.byType(Title).first).title,
        'PrinterHub',
      );
    });

    group('for someone new', () {
      testWidgets('opens on the welcome screens, then asks to sign in', (
        tester,
      ) async {
        final preferences = await pump(tester, welcomed: false);
        expect(find.byType(WelcomePage), findsOneWidget);

        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();

        expect(find.byType(SignInPage), findsOneWidget);
        verify(preferences.completeOnboarding).called(1);
      });

      testWidgets('registers, names a workspace, and lands on Home', (
        tester,
      ) async {
        await pump(tester);
        await tester.tap(find.text('New here? Create an account'));
        await tester.pumpAndSettle();
        expect(find.byType(RegisterPage), findsOneWidget);

        await tester.fill('Your name', 'Grace Hopper');
        await tester.fill('Email', 'grace@example.com');
        await tester.fill('Password', 'long enough');
        await tester.ensureVisible(find.text('Create account'));
        await tester.tap(find.text('Create account'));
        await tester.pumpAndSettle();

        expect(find.byType(CreateWorkspacePage), findsOneWidget);
        expect(find.text("Grace's workspace"), findsOneWidget);

        await tester.ensureVisible(find.text('Continue'));
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(find.byType(HomePage), findsOneWidget);
        expect(find.byType(AppNotice), findsOneWidget);
      });

      testWidgets('signs in to an account that has a workspace', (
        tester,
      ) async {
        backend.workspaces = [organizationBody()];
        await pump(tester);

        await tester.fill('Email', 'ada@example.com');
        await tester.fill('Password', 'correct horse');
        await tester.tap(find.text('Sign in'));
        await tester.pumpAndSettle();

        expect(find.byType(HomePage), findsOneWidget);
      });

      testWidgets('keeps a file another app handed over until they are '
          'signed in, then opens printing', (tester) async {
        backend
          ..workspaces = [organizationBody()]
          ..printerList = [printerBody()];
        await pump(tester);

        backend.otherApps.open(pickedPdf(name: 'Boarding pass.pdf'));
        await tester.pumpAndSettle();
        expect(find.byType(SignInPage), findsOneWidget);

        await tester.fill('Email', 'ada@example.com');
        await tester.fill('Password', 'correct horse');
        await tester.tap(find.text('Sign in'));
        await tester.pumpAndSettle();

        expect(find.byType(PrintPage), findsOneWidget);
        expect(find.text('Boarding pass.pdf'), findsOneWidget);
      });

      testWidgets('walks through password reset back to sign-in', (
        tester,
      ) async {
        await pump(tester);
        await tester.tap(find.text('Forgot password?'));
        await tester.pumpAndSettle();

        await tester.fill('Email', 'ada@example.com');
        await tester.tap(find.text('Send code'));
        await tester.pumpAndSettle();
        expect(find.byType(ResetPasswordPage), findsOneWidget);
        expect(find.textContaining('ada@example.com'), findsOneWidget);

        await tester.fill('6-digit code', '123456');
        await tester.fill('New password', 'new password');
        await tester.ensureVisible(find.text('Change password'));
        await tester.tap(find.text('Change password'));
        await tester.pumpAndSettle();

        expect(find.byType(SignInPage), findsOneWidget);
      });
    });

    group('for someone signed in', () {
      setUp(() => backend.signedInBefore());

      testWidgets('opens on Home in the default theme', (tester) async {
        await pump(tester);

        expect(find.byType(HomePage), findsOneWidget);
        expect(coloursOf(tester, HomePage), AppTheme.mint.light.colors);
      });

      testWidgets('opens in the theme chosen on an earlier launch', (
        tester,
      ) async {
        await pump(tester, themeName: 'volt');

        expect(coloursOf(tester, HomePage), AppTheme.volt.light.colors);
      });

      testWidgets('refreshes the account after opening', (tester) async {
        await pump(tester);

        expect(backend.sent('GET /users/me'), hasLength(1));
        expect(backend.sent('GET /organizations'), hasLength(1));
      });

      testWidgets('moves between the four areas', (tester) async {
        await pump(tester);

        await openArea(tester, 'Printers');
        expect(find.byType(PrintersPage), findsOneWidget);

        await openArea(tester, 'Activity');
        expect(find.byType(ActivityPage), findsOneWidget);

        await openArea(tester, 'Settings');
        expect(find.byType(SettingsPage), findsOneWidget);

        await openArea(tester, 'Home');
        expect(find.byType(HomePage), findsOneWidget);
      });

      /// Opens an entry of Settings, which may be further down the list
      /// than the screen is tall.
      Future<void> openEntry(WidgetTester tester, String title) async {
        await tester.scrollUntilVisible(
          find.text(title),
          200,
          scrollable: find
              .descendant(
                of: find.byType(SettingsPage),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.ensureVisible(find.text(title));
        await tester.pumpAndSettle();
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
      }

      testWidgets('opens the ways a printer is reached from its page', (
        tester,
      ) async {
        backend.printerList = [printerBody()];
        await pump(tester);
        await openArea(tester, 'Printers');
        await tester.tap(find.text('Front desk'));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Manage'),
          200,
          scrollable: find
              .descendant(
                of: find.byType(PrinterDetailPage),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.ensureVisible(find.text('Manage'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Manage'));
        await tester.pumpAndSettle();

        expect(find.byType(PrinterConnectionsPage), findsOneWidget);
        expect(find.text('Printing · 192.168.1.40'), findsOneWidget);
      });

      testWidgets('opens printing from a printer’s page', (tester) async {
        backend.printerList = [printerBody()];
        await pump(tester);
        await openArea(tester, 'Printers');
        await tester.tap(find.text('Front desk'));
        await tester.pumpAndSettle();

        final print = find.widgetWithText(FilledButton, 'Print');
        await tester.scrollUntilVisible(
          print,
          200,
          scrollable: find
              .descendant(
                of: find.byType(PrinterDetailPage),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.ensureVisible(print);
        await tester.pumpAndSettle();
        await tester.tap(print);
        await tester.pumpAndSettle();

        expect(find.byType(PrintPage), findsOneWidget);
        expect(find.text('What would you like to print?'), findsOneWidget);
      });

      testWidgets('opens printing on a document handed over', (tester) async {
        backend.printerList = [printerBody()];
        await pump(tester);

        // As a finished scan or a kept document does.
        GoRouter.of(tester.element(find.byType(HomePage))).go(
          AppRoutes.printOn('printer-1'),
          extra: pickedPdf(name: 'Scan today.pdf'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(PrintPage), findsOneWidget);
        expect(find.text('Scan today.pdf'), findsOneWidget);
        expect(find.text('How to print it'), findsOneWidget);
      });

      group('with a file another app hands over', () {
        testWidgets('opens printing on the only printer', (tester) async {
          backend.printerList = [printerBody()];
          await pump(tester);

          backend.otherApps.open(pickedPdf(name: 'Boarding pass.pdf'));
          await tester.pumpAndSettle();

          expect(find.byType(PrintPage), findsOneWidget);
          expect(find.text('Boarding pass.pdf'), findsOneWidget);
          expect(find.text('How to print it'), findsOneWidget);
        });

        testWidgets('opens printing when the file is what started the app', (
          tester,
        ) async {
          backend.printerList = [printerBody()];
          backend.otherApps.open(pickedPdf(name: 'Boarding pass.pdf'));

          await pump(tester);

          expect(find.byType(PrintPage), findsOneWidget);
          expect(find.text('Boarding pass.pdf'), findsOneWidget);
        });

        testWidgets('asks which printer when there are several', (
          tester,
        ) async {
          backend.printerList = [
            printerBody(),
            printerBody(id: 'printer-2', name: 'Back office'),
          ];
          await pump(tester);

          backend.otherApps.open(pickedPdf(name: 'Boarding pass.pdf'));
          await tester.pumpAndSettle();
          expect(find.text('Which printer?'), findsOneWidget);
          expect(find.byType(PrintPage), findsNothing);

          await tester.tap(
            find.descendant(
              of: find.byType(BottomSheet),
              matching: find.text('Back office'),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(PrintPage), findsOneWidget);
          expect(find.text('Boarding pass.pdf'), findsOneWidget);
          expect(
            tester.widget<PrintPage>(find.byType(PrintPage)).printerId,
            'printer-2',
          );
        });

        testWidgets('stays where it was when no printer is chosen', (
          tester,
        ) async {
          backend.printerList = [
            printerBody(),
            printerBody(id: 'printer-2', name: 'Back office'),
          ];
          await pump(tester);
          backend.otherApps.open(pickedPdf());
          await tester.pumpAndSettle();

          await tester.tapAt(const Offset(20, 20));
          await tester.pumpAndSettle();

          expect(find.text('Which printer?'), findsNothing);
          expect(find.byType(HomePage), findsOneWidget);
        });

        testWidgets('opens the printers when there is none to print on', (
          tester,
        ) async {
          await pump(tester);

          backend.otherApps.open(pickedPdf());
          await tester.pumpAndSettle();

          expect(find.byType(PrintersPage), findsOneWidget);
          expect(find.byType(PrintPage), findsNothing);
        });

        testWidgets('leaves alone a kind of file it cannot print', (
          tester,
        ) async {
          backend.printerList = [printerBody()];
          await pump(tester);

          backend.otherApps.open(pickedPdf(name: 'Budget.xlsx'));
          await tester.pumpAndSettle();

          expect(find.byType(HomePage), findsOneWidget);
        });
      });

      testWidgets('opens scanning with the phone alone from Home', (
        tester,
      ) async {
        backend.features = {'camera_scan': true};
        await pump(tester);
        await tester.pumpAndSettle();

        final scan = find.text('Scan with your phone');
        await tester.scrollUntilVisible(
          scan,
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(scan);
        await tester.pumpAndSettle();

        expect(find.byType(ScanPage), findsOneWidget);
        expect(find.text("Use your phone's camera"), findsOneWidget);
      });

      testWidgets('opens the Tools screen from Home', (tester) async {
        await pump(tester);
        await tester.pumpAndSettle();
        final all = find.descendant(
          of: find.ancestor(of: find.text('Tools'), matching: find.byType(Row)),
          matching: find.text('See all'),
        );
        await tester.scrollUntilVisible(
          all,
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        await tester.tap(all);
        await tester.pumpAndSettle();

        expect(find.byType(ToolsPage), findsOneWidget);
      });

      testWidgets('opens each tool from the Tools screen', (tester) async {
        backend.features = {'local_ocr': true};
        backend.picker.pictures = [];
        await pump(tester);
        await tester.pumpAndSettle();

        for (final (tool, screen) in [
          ('Extract text', ExtractTextPage),
          ('Pictures to PDF', ScanPage),
          ('Print photos', PhotoSheetPage),
          ('PDF to pictures', PdfPicturesPage),
          ('PDF to long picture', PdfPicturesPage),
        ]) {
          GoRouter.of(tester.element(find.byType(HomePage)))
              .go(AppRoutes.tools);
          await tester.pumpAndSettle();
          final tile = find.text(tool);
          await tester.scrollUntilVisible(
            tile,
            120,
            scrollable: find
                .descendant(
                  of: find.byType(ToolsPage),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          await tester.tap(tile);
          await tester.pumpAndSettle();
          expect(find.byType(screen), findsOneWidget);

          GoRouter.of(tester.element(find.byType(screen))).go(AppRoutes.home);
          await tester.pumpAndSettle();
        }
      });

      testWidgets('opens copying from a printer’s page', (tester) async {
        backend.printerList = [printerBody()];
        await pump(tester);
        await openArea(tester, 'Printers');
        await tester.tap(find.text('Front desk'));
        await tester.pumpAndSettle();

        final copy = find.widgetWithText(OutlinedButton, 'Copy');
        await tester.scrollUntilVisible(
          copy,
          200,
          scrollable: find
              .descendant(
                of: find.byType(PrinterDetailPage),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.ensureVisible(copy);
        await tester.pumpAndSettle();
        await tester.tap(copy);
        await tester.pumpAndSettle();

        expect(find.byType(CopyPage), findsOneWidget);
      });

      testWidgets('opens scanning from a printer’s page', (tester) async {
        backend.printerList = [printerBody()];
        await pump(tester);
        await openArea(tester, 'Printers');
        await tester.tap(find.text('Front desk'));
        await tester.pumpAndSettle();

        final scan = find.widgetWithText(OutlinedButton, 'Scan');
        await tester.scrollUntilVisible(
          scan,
          200,
          scrollable: find
              .descendant(
                of: find.byType(PrinterDetailPage),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.ensureVisible(scan);
        await tester.pumpAndSettle();
        await tester.tap(scan);
        await tester.pumpAndSettle();

        expect(find.byType(ScanPage), findsOneWidget);
        expect(find.text('How to scan it'), findsOneWidget);
      });

      testWidgets('settles a job the app was closed during, as it starts '
          'and as it comes back', (tester) async {
        backend
          ..printerList = [printerBody()]
          ..plugInPrinter();
        // Each was started by an earlier run of the app and never ended.
        Future<String> closedDuringPrint() async {
          final before = JobsRepository(
            client: backend.client,
            store: backend.store,
          );
          final job = await before.startPrint(
            organizationId: '0198c0de-0000-7000-8000-00000000000b',
            printerId: 'printer-1',
            title: 'Closed.pdf',
            choices: const PrintChoices(),
          );
          await before.report(
            '0198c0de-0000-7000-8000-00000000000b',
            job.id,
            const JobUpdate(status: 'printing', printerJobRef: '1'),
          );
          return job.id;
        }

        String statusOf(String id) =>
            backend.jobList.firstWhere((job) => job['id'] == id)['status']!
                as String;

        final first = (await tester.runAsync(closedDuringPrint))!;
        await pump(tester);
        expect(statusOf(first), 'completed');

        final second = (await tester.runAsync(closedDuringPrint))!;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(statusOf(second), 'completed');
      });

      testWidgets('counts what is unread, again as the app comes back, and '
          'opens it', (tester) async {
        backend.notificationList = [notificationBody()];
        await pump(tester);
        final badge = find.byType(Badge);
        expect(
          find.descendant(of: badge, matching: find.text('1')),
          findsOneWidget,
        );

        backend.notificationList = [
          notificationBody(id: 'notification-2', title: 'Scan ready'),
          ...backend.notificationList,
        ];
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: badge, matching: find.text('2')),
          findsOneWidget,
        );

        await tester.tap(find.byTooltip('Notifications'));
        await tester.pumpAndSettle();

        expect(find.byType(NotificationsPage), findsOneWidget);
        expect(find.text('Scan ready'), findsOneWidget);
      });

      testWidgets('opens the documents from Activity', (tester) async {
        backend.documentList = [documentBody()];
        await pump(tester);
        await openArea(tester, 'Activity');

        await tester.tap(find.byTooltip('Documents'));
        await tester.pumpAndSettle();

        expect(find.byType(DocumentsPage), findsOneWidget);
        expect(find.text('Receipts.pdf'), findsOneWidget);
      });

      testWidgets('opens a job from Activity, and prints it again', (
        tester,
      ) async {
        backend
          ..printerList = [printerBody()]
          ..jobList = [jobBody(status: 'failed', copies: 3)]
          ..jobEvents['job-1'] = [];
        await pump(tester);
        await openArea(tester, 'Activity');

        await tester.tap(find.text('Report.pdf'));
        await tester.pumpAndSettle();
        expect(find.byType(JobPage), findsOneWidget);

        await tester.tap(find.text('Print it again'));
        await tester.pumpAndSettle();

        // In the Printers area, on that printer, with the job's choices.
        expect(find.byType(PrintPage), findsOneWidget);
        final cubit = BlocProvider.of<PrintCubit>(
          tester.element(find.byType(PrintView)),
        );
        expect(cubit.state.choices.copies, 3);
      });

      testWidgets('opens the catalogue from Add a printer', (tester) async {
        await pump(tester);
        await openArea(tester, 'Printers');
        await tester.tap(find.text('Add a printer'));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        await tester.scrollUntilVisible(
          find.text('Browse the catalogue'),
          200,
          scrollable: find
              .descendant(
                of: find.byType(AddPrinterPage),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.ensureVisible(find.text('Browse the catalogue'));
        await tester.pump();
        await tester.tap(find.text('Browse the catalogue'));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(find.byType(CataloguePage), findsOneWidget);
        expect(find.text('Xerox VersaLink C7100 Series'), findsOneWidget);
      });

      testWidgets('opens the workspace screens from Settings', (tester) async {
        backend
          ..features = {'local_ocr': true}
          ..auditList = [auditBody()];
        await pump(tester);
        // What is switched on for the workspace was read as the app began.
        final features = BlocProvider.of<FeaturesCubit>(
          tester.element(find.byType(HomePage)),
        );
        expect(features.enabled('local_ocr'), isTrue);
        await openArea(tester, 'Settings');

        await openEntry(tester, 'Name and rules');
        expect(find.byType(WorkspacePage), findsOneWidget);
        await tester.tap(find.text('What has been done'));
        await tester.pumpAndSettle();
        expect(find.byType(WorkspaceLogPage), findsOneWidget);
        expect(find.text('Printer created'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();

        await openEntry(tester, 'People');
        expect(find.byType(MembersPage), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();

        await openEntry(tester, 'Invitations');
        expect(find.byType(InvitationsPage), findsOneWidget);
      });

      testWidgets('leaving the only workspace asks for a new one', (
        tester,
      ) async {
        await pump(tester);
        await openArea(tester, 'Settings');
        await openEntry(tester, 'Name and rules');

        await tester.ensureVisible(find.text('Leave this workspace'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Leave this workspace'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Leave'));
        await tester.pumpAndSettle();

        expect(find.byType(CreateWorkspacePage), findsOneWidget);
      });

      testWidgets('opens each account screen from Settings', (tester) async {
        await pump(tester);
        await openArea(tester, 'Settings');

        for (final (entry, page) in [
          ('Ada', ProfilePage),
          ('Change password', ChangePasswordPage),
          ('Devices and sessions', DevicesPage),
          ('Delete account', DeleteAccountPage),
        ]) {
          await openEntry(tester, entry);
          expect(find.byType(page), findsOneWidget, reason: entry);

          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(find.byType(SettingsPage), findsOneWidget);
        }
      });

      testWidgets('changes theme in Settings and keeps it', (tester) async {
        final preferences = await pump(tester);

        await openArea(tester, 'Settings');
        await openEntry(tester, 'Theme');
        expect(find.byType(ThemePage), findsOneWidget);

        await tester.tap(find.text('Indigo'));
        await tester.pumpAndSettle();
        expect(coloursOf(tester, ThemePage), AppTheme.indigo.light.colors);
        expect(preferences.themeName, 'indigo');

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(SettingsPage), findsOneWidget);
        expect(find.text('Indigo'), findsOneWidget);

        await openArea(tester, 'Home');
        expect(coloursOf(tester, HomePage), AppTheme.indigo.light.colors);
      });

      testWidgets(
        'returns to the top of an area when its tab is tapped again',
        (tester) async {
          await pump(tester);
          await openArea(tester, 'Settings');
          await openEntry(tester, 'Design gallery');
          expect(find.byType(GalleryPage), findsOneWidget);

          await openArea(tester, 'Settings');

          expect(find.byType(GalleryPage), findsNothing);
          expect(find.byType(SettingsPage), findsOneWidget);
        },
      );

      testWidgets('keeps the place in an area while visiting another', (
        tester,
      ) async {
        await pump(tester);
        await openArea(tester, 'Settings');
        await openEntry(tester, 'Theme');

        await openArea(tester, 'Home');
        await openArea(tester, 'Settings');

        expect(find.byType(ThemePage), findsOneWidget);
      });

      testWidgets('verifies the email from the reminder on Home', (
        tester,
      ) async {
        await pump(tester);

        await tester.tap(find.text('Verify your email'));
        await tester.pumpAndSettle();
        expect(find.byType(VerifyEmailPage), findsOneWidget);

        await tester.fill('6-digit code', '123456');
        await tester.tap(find.text('Verify'));
        await tester.pumpAndSettle();

        expect(find.byType(HomePage), findsOneWidget);
        expect(find.byType(AppNotice), findsNothing);
      });

      testWidgets('adds a printer found on the network and shows it', (
        tester,
      ) async {
        backend.plugInPrinter();
        await pump(tester);
        await openArea(tester, 'Printers');
        expect(find.text('No printers yet'), findsOneWidget);

        await tester.tap(find.text('Add a printer'));
        // The list of ways shows a spinner while it looks for printers, so
        // it never settles: time is moved on by hand.
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.ensureVisible(find.text('Enter an address'));
        await tester.tap(find.text('Enter an address'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, '192.168.1.40');
        await tester.tap(find.text('Find printer'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Add printer'));
        await tester.tap(find.text('Add printer'));
        await tester.pumpAndSettle();

        expect(find.byType(PrintersPage), findsOneWidget);
        expect(find.byType(PrinterCard), findsOneWidget);
        expect(find.text('Ready'), findsOneWidget);

        await tester.tap(find.byType(PrinterCard));
        await tester.pumpAndSettle();
        expect(find.byType(PrinterDetailPage), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();
        await openArea(tester, 'Home');
        expect(find.text('Your printers'), findsOneWidget);
      });

      testWidgets('returns to sign-in after signing out', (tester) async {
        await pump(tester);
        await openArea(tester, 'Settings');

        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();

        expect(find.byType(SignInPage), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
      });
    });
  });
}
