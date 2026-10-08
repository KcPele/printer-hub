import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/account/account.dart';
import 'package:printerhub/session/session.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;
  late MockGoRouter router;

  setUp(() async {
    backend = TestBackend();
    router = recordingRouter();
    await backend.signedInBefore();
  });
  tearDown(() => backend.close());

  Future<void> pump(WidgetTester tester, Widget page) async {
    await tester.pumpApp(page, backend: backend, router: router);
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.widgetWithText(FilledButton, label));
    await tester.tap(find.widgetWithText(FilledButton, label));
    await tester.pumpAndSettle();
  }

  group('ProfilePage', () {
    testWidgets('shows the name to change and the email as it is', (
      tester,
    ) async {
      await pump(tester, const ProfilePage());

      expect(find.widgetWithText(TextFormField, 'Ada'), findsOneWidget);
      final email = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'ada@example.com'),
      );
      expect(email.enabled, isFalse);
    });

    testWidgets('saves the new name and goes back', (tester) async {
      await pump(tester, const ProfilePage());
      await tester.fill('Your name', '  Ada Lovelace ');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(backend.user['name'], 'Ada Lovelace');
      expect(find.text('Your name was changed.'), findsOneWidget);
      verify(router.pop).called(1);
    });

    testWidgets('needs a name', (tester) async {
      await pump(tester, const ProfilePage());
      await tester.fill('Your name', ' ');

      await press(tester, 'Save');

      expect(backend.user['name'], 'Ada');
      verifyNever(router.pop);
    });

    testWidgets('says why the name could not be saved', (tester) async {
      await pump(tester, const ProfilePage());
      backend.offline = true;

      await press(tester, 'Save');

      expect(find.textContaining("Can't reach PrinterHub"), findsOneWidget);
      verifyNever(router.pop);
    });
  });

  group('ChangePasswordPage', () {
    testWidgets('changes the password and goes back', (tester) async {
      await pump(tester, const ChangePasswordPage());
      await tester.fill('Current password', 'old password');
      await tester.fill('New password', 'new password 1');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(backend.network.requests.last.data, {
        'current_password': 'old password',
        'new_password': 'new password 1',
      });
      expect(find.text('Your password was changed.'), findsOneWidget);
      verify(router.pop).called(1);
    });

    testWidgets('needs the current password and a long enough new one', (
      tester,
    ) async {
      await pump(tester, const ChangePasswordPage());
      final sent = backend.network.requests.length;
      await tester.fill('New password', 'short');

      await press(tester, 'Change password');

      expect(find.textContaining('at least 8'), findsOneWidget);
      expect(backend.network.requests, hasLength(sent));
    });

    testWidgets('says when the current password is wrong', (tester) async {
      backend.fail(
        'POST /auth/password/change',
        401,
        'auth.invalid_credentials',
      );
      await pump(tester, const ChangePasswordPage());
      await tester.fill('Current password', 'a guess');
      await tester.fill('New password', 'new password 1');

      await press(tester, 'Change password');

      expect(find.byType(SnackBar), findsNothing);
      verifyNever(router.pop);
      expect(find.widgetWithText(FilledButton, 'Change password'), findsOne);
    });
  });

  group('DeleteAccountPage', () {
    testWidgets('warns that it cannot be undone', (tester) async {
      await pump(tester, const DeleteAccountPage());

      expect(find.text('This cannot be undone.'), findsOneWidget);
      expect(find.textContaining('signs you out everywhere'), findsOneWidget);
    });

    testWidgets('needs the password', (tester) async {
      await pump(tester, const DeleteAccountPage());

      await press(tester, 'Delete my account');

      expect(backend.auth.user, isNotNull);
    });

    testWidgets('deletes the account and ends the session', (tester) async {
      final session = SessionCubit(
        authRepository: backend.auth,
        organizationsRepository: backend.organizations,
        preferencesRepository: emptyPreferences(),
        keptOrganizations: await backend.organizations.kept(),
      );
      addTearDown(session.close);
      await tester.pumpApp(
        const DeleteAccountPage(),
        backend: backend,
        sessionCubit: session,
        router: router,
      );
      await tester.fill('Password', 'correct horse');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(backend.network.requests.last.data, {'password': 'correct horse'});
      expect(session.state.stage, SessionStage.signedOut);
    });
  });

  group('DevicesPage', () {
    Future<void> open(WidgetTester tester) async {
      await tester.runAsync(backend.auth.registerDevice);
      await pump(tester, const DevicesPage());
    }

    testWidgets('lists where the account is signed in, and its phones', (
      tester,
    ) async {
      await open(tester);

      // This phone, as a session and as a device.
      expect(find.text('iPhone 15 Pro'), findsNWidgets(2));
      expect(find.text('This device'), findsNWidgets(2));
      // Another session, which says only what app it is.
      expect(find.text('PrinterHub/1.0 Android'), findsOneWidget);
      expect(find.textContaining('Last used'), findsNWidgets(2));
      expect(find.text('Pixel 8'), findsOneWidget);
      expect(find.text('Android 15 · Notifications on'), findsOneWidget);
      expect(find.text('iOS 18.1 · Notifications off'), findsOneWidget);
    });

    testWidgets('signs another device out', (tester) async {
      await open(tester);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(find.text('PrinterHub/1.0 Android'), findsNothing);
      expect(backend.sessionList, hasLength(1));
    });

    testWidgets('names a phone', (tester) async {
      await open(tester);
      expect(find.textContaining('Tap one to give it a name'), findsOneWidget);

      await tester.tap(find.text('Pixel 8'));
      await tester.pumpAndSettle();
      // Nothing to save until there is a name.
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), 'Work phone');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Work phone'), findsOneWidget);
      expect(find.text('Pixel 8'), findsNothing);
      expect(backend.deviceList.last['name'], 'Work phone');
    });

    testWidgets('leaves a phone as it was when naming it is given up', (
      tester,
    ) async {
      await open(tester);

      await tester.tap(find.text('Pixel 8'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Pixel 8'), findsOneWidget);
      expect(backend.deviceList.last['name'], isNull);
    });

    testWidgets('forgets a phone', (tester) async {
      await open(tester);

      await tester.tap(find.text('Forget'));
      await tester.pumpAndSettle();

      expect(find.text('Pixel 8'), findsNothing);
      expect(backend.deviceList, hasLength(1));
    });

    testWidgets('shows progress while a device is being signed out', (
      tester,
    ) async {
      await open(tester);

      await tester.tap(find.text('Sign out'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('names a session that says nothing about itself', (
      tester,
    ) async {
      backend.sessionList = [
        {...backend.sessionList.last, 'user_agent': null},
      ];
      backend.deviceList = [];

      await pump(tester, const DevicesPage());

      expect(find.text('Unknown device'), findsOneWidget);
      expect(find.text('Phones and tablets'), findsNothing);
    });

    testWidgets('says when a change could not be made', (tester) async {
      await open(tester);
      backend.offline = true;

      await tester.tap(find.text('Forget'));
      await tester.pumpAndSettle();

      expect(find.textContaining("Can't reach PrinterHub"), findsOneWidget);
      expect(find.text('Pixel 8'), findsOneWidget);
    });

    testWidgets('says when the list cannot be read, and tries again', (
      tester,
    ) async {
      backend.offline = true;
      await pump(tester, const DevicesPage());

      expect(find.text("Couldn't load your devices"), findsOneWidget);

      backend.offline = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Signed in'), findsOneWidget);
    });

    testWidgets('reads the list again when pulled down', (tester) async {
      await open(tester);
      backend.sessionList = [backend.sessionList.first];

      await tester.fling(find.text('Signed in'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(find.text('PrinterHub/1.0 Android'), findsNothing);
    });
  });
}
