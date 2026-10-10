import 'dart:io';

import 'package:api_client/testing.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/session/session.dart';
import 'package:printerhub/settings/settings.dart';
import 'package:printerhub/theme/theme.dart';

import '../../helpers/helpers.dart';

void main() {
  group('SettingsPage', () {
    late TestBackend backend;

    setUp(() => backend = TestBackend());
    tearDown(() => backend.close());

    group('sync', () {
      const org = '0198c0de-0000-7000-8000-00000000000b';

      testWidgets('says everything is in the account when it is', (
        tester,
      ) async {
        await tester.runAsync(backend.signedInBefore);
        await tester.pumpApp(const SettingsPage(), backend: backend);
        await tester.scrollUntilVisible(find.text('Sync now'), 200);

        expect(find.text('Everything is in your account'), findsOneWidget);
        expect(find.text('Not synced yet'), findsOneWidget);
        expect(find.textContaining('saved to your account'), findsOneWidget);
      });

      testWidgets('says what waits on the phone, and sends it when '
          'asked', (tester) async {
        await tester.runAsync(backend.signedInBefore);
        await tester.runAsync(
          () => backend.library.add(
            organizationId: org,
            file: File('${backend.scans.path}/Note.pdf')
              ..writeAsStringSync('%PDF'),
            mimeType: 'application/pdf',
          ),
        );
        await tester.pumpApp(const SettingsPage(), backend: backend);
        await tester.pump();
        await tester.scrollUntilVisible(find.text('Sync now'), 200);
        expect(
          find.text('1 document is waiting on this phone'),
          findsOneWidget,
        );

        await tester.ensureVisible(find.text('Sync now'));
        await tester.pump();
        await tester.tap(find.text('Sync now'));
        await tester.pump();
        expect(find.text('Syncing'), findsOneWidget);
        for (var i = 0; i < 50; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(const Duration(milliseconds: 20));
          if (find.text('Syncing').evaluate().isEmpty) break;
        }

        expect(find.text('Everything is in your account'), findsOneWidget);
        expect(find.textContaining('Last synced'), findsOneWidget);
        expect(backend.documentList, hasLength(1));
      });

      testWidgets('is not shown to someone with no workspace', (tester) async {
        await tester.pumpApp(const SettingsPage(), backend: backend);

        expect(find.text('Sync now'), findsNothing);
      });
    });

    testWidgets('shows the theme in use', (tester) async {
      await tester.pumpApp(
        const SettingsPage(),
        backend: backend,
        preferencesRepository: emptyPreferences(themeName: 'indigo'),
      );

      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Indigo'), findsOneWidget);
    });

    testWidgets('shows the new theme as soon as it changes', (tester) async {
      final cubit = ThemeCubit(preferencesRepository: emptyPreferences());
      await tester.pumpApp(
        const SettingsPage(),
        backend: backend,
        themeCubit: cubit,
      );
      expect(find.text('Mint'), findsOneWidget);

      await cubit.select(AppThemeId.volt);
      await tester.pumpAndSettle();

      expect(find.text('Volt'), findsOneWidget);
    });

    testWidgets('opens the theme screen and the design gallery', (
      tester,
    ) async {
      final router = recordingRouter();
      await tester.pumpApp(
        const SettingsPage(),
        backend: backend,
        router: router,
      );

      await tester.tap(find.text('Theme'));
      await tester.tap(find.text('Design gallery'));

      verify(() => router.push<Object?>(AppRoutes.theme)).called(1);
      verify(() => router.push<Object?>(AppRoutes.gallery)).called(1);
    });

    testWidgets('has no account section when signed out', (tester) async {
      await tester.pumpApp(const SettingsPage(), backend: backend);

      expect(find.text('Account'), findsNothing);
      expect(find.text('Sign out'), findsNothing);
    });

    group('when signed in', () {
      late SessionCubit session;

      Future<void> pump(WidgetTester tester, {MockGoRouter? router}) async {
        await tester.runAsync(backend.signedInBefore);
        session = SessionCubit(
          authRepository: backend.auth,
          organizationsRepository: backend.organizations,
          preferencesRepository: emptyPreferences(),
          keptOrganizations: await backend.organizations.kept(),
        );
        addTearDown(session.close);
        await tester.pumpApp(
          const SettingsPage(),
          backend: backend,
          sessionCubit: session,
          router: router,
        );
      }

      testWidgets('shows who is signed in and their workspace', (tester) async {
        await pump(tester);

        expect(find.text('Account'), findsOneWidget);
        expect(find.text('Ada'), findsOneWidget);
        expect(find.text('ada@example.com'), findsOneWidget);
        expect(find.text('Workspace'), findsOneWidget);
        expect(find.text('Acme'), findsOneWidget);
      });

      testWidgets('opens each account screen', (tester) async {
        final router = recordingRouter();
        await pump(tester, router: router);

        for (final (entry, route) in [
          ('Ada', AppRoutes.profile),
          ('Change password', AppRoutes.changePassword),
          ('Devices and sessions', AppRoutes.devices),
          ('Delete account', AppRoutes.deleteAccount),
        ]) {
          await tester.ensureVisible(find.text(entry));
          await tester.tap(find.text(entry));

          verify(() => router.push<Object?>(route)).called(1);
        }
      });

      testWidgets('opens the workspace, its people, and invitations', (
        tester,
      ) async {
        final router = recordingRouter();
        await pump(tester, router: router);

        expect(find.text('Your workspace'), findsOneWidget);
        // What the person is in the workspace sits under its entry.
        expect(find.text('Owner'), findsOneWidget);
        for (final (entry, route) in [
          ('Name and rules', AppRoutes.workspace),
          ('People', AppRoutes.members),
          ('Invitations', AppRoutes.invitations),
        ]) {
          await tester.ensureVisible(find.text(entry));
          await tester.pump();
          await tester.tap(find.text(entry));

          verify(() => router.push<Object?>(route)).called(1);
        }
      });

      testWidgets('offers to verify an unverified email', (tester) async {
        final router = recordingRouter();
        await pump(tester, router: router);

        await tester.tap(find.text('Verify email'));

        verify(() => router.push<Object?>(AppRoutes.verifyEmail)).called(1);
      });

      testWidgets('does not offer it once the email is verified', (
        tester,
      ) async {
        backend.user = {
          ...backend.user,
          'email_verified_at': '2026-10-07T11:00:00Z',
        };
        await pump(tester);

        expect(find.text('Verify email'), findsNothing);
      });

      testWidgets('has nothing to choose with a single workspace', (
        tester,
      ) async {
        await pump(tester);

        await tester.tap(find.text('Workspace'));
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsNothing);
      });

      testWidgets('switches between workspaces', (tester) async {
        backend.workspaces = [
          organizationBody(id: 'acme'),
          organizationBody(id: 'globex', name: 'Globex', role: 'user'),
        ];
        await pump(tester);

        await tester.tap(find.text('Workspace'));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.check), findsOneWidget);

        await tester.tap(find.text('Globex'));
        await tester.pumpAndSettle();

        expect(session.state.organization?.name, 'Globex');
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.text('Globex'), findsOneWidget);
      });

      testWidgets('signs out', (tester) async {
        await pump(tester);

        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();

        expect(session.state.stage, SessionStage.signedOut);
        expect(backend.sent('POST /auth/logout'), hasLength(1));
      });
    });
  });
}
