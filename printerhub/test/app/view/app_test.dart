import 'package:api_client/testing.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/activity/activity.dart';
import 'package:printerhub/auth/auth.dart';
import 'package:printerhub/gallery/gallery.dart';
import 'package:printerhub/home/home.dart';
import 'package:printerhub/printers/printers.dart';
import 'package:printerhub/session/session.dart';
import 'package:printerhub/settings/settings.dart';
import 'package:printerhub/theme/theme.dart';
import 'package:printerhub/welcome/welcome.dart';

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

      testWidgets('changes theme in Settings and keeps it', (tester) async {
        final preferences = await pump(tester);

        await openArea(tester, 'Settings');
        await tester.tap(find.text('Theme'));
        await tester.pumpAndSettle();
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
          await tester.scrollUntilVisible(find.text('Design gallery'), 200);
          await tester.tap(find.text('Design gallery'));
          await tester.pumpAndSettle();
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
        await tester.tap(find.text('Theme'));
        await tester.pumpAndSettle();

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
