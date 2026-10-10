import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:organizations_repository/organizations_repository.dart';
import 'package:preferences_repository/preferences_repository.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/auth/auth.dart';
import 'package:printerhub/home/home.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/notifications/notifications.dart';
import 'package:printerhub/printers/printers.dart';
import 'package:printerhub/scan/scan.dart';
import 'package:printerhub/session/session.dart';
import 'package:printerhub/theme/theme.dart';
import 'package:printerhub/welcome/welcome.dart';
import 'package:printerhub/workspace/workspace.dart';
import 'package:printers_repository/printers_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  group('createAppRouter', () {
    late TestBackend backend;

    setUp(() => backend = TestBackend());
    tearDown(() => backend.close());

    /// Opens the app's routes at [location], as a link or a restart would.
    Future<void> open(
      WidgetTester tester,
      String location, {
      bool welcomed = true,
      bool useKept = true,
    }) async {
      final preferences = emptyPreferences(onboardingCompleted: welcomed);
      final session = SessionCubit(
        authRepository: backend.auth,
        organizationsRepository: backend.organizations,
        preferencesRepository: preferences,
        keptOrganizations: useKept ? await backend.organizations.kept() : null,
      );
      addTearDown(session.close);
      final router = createAppRouter(
        preferencesRepository: preferences,
        sessionCubit: session,
        initialLocation: location,
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<PreferencesRepository>.value(value: preferences),
            RepositoryProvider<AuthRepository>.value(value: backend.auth),
            RepositoryProvider<OrganizationsRepository>.value(
              value: backend.organizations,
            ),
            RepositoryProvider<PrintersRepository>.value(
              value: backend.printers,
            ),
            RepositoryProvider<PrinterFinders>.value(value: backend.finders),
            RepositoryProvider<PageCamera>.value(value: backend.camera),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => ThemeCubit(preferencesRepository: preferences),
              ),
              BlocProvider.value(value: session),
              BlocProvider(
                create: (_) =>
                    BrightnessCubit(preferencesRepository: preferences),
              ),
              BlocProvider(
                create: (_) => PrintersCubit(
                  printersRepository: backend.printers,
                  organizationId: session.state.organization?.id,
                  organizationChanges: const Stream.empty(),
                ),
              ),
              BlocProvider(
                create: (_) => UnreadCubit(
                  notificationsRepository: backend.notifications,
                  signedInChanges: const Stream.empty(),
                ),
              ),
              BlocProvider(
                create: (_) => FeaturesCubit(
                  organizationsRepository: backend.organizations,
                  organizationChanges: const Stream.empty(),
                ),
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.mint.data(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        ),
      );
      // Some screens show a spinner that never settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('sends a new install to the welcome screens', (tester) async {
      await open(tester, AppRoutes.settings, welcomed: false);

      expect(find.byType(WelcomePage), findsOneWidget);
    });

    testWidgets('sends a signed-out person to sign in', (tester) async {
      await open(tester, AppRoutes.home);
      expect(find.byType(SignInPage), findsOneWidget);

      await open(tester, AppRoutes.welcome);
      expect(find.byType(SignInPage), findsOneWidget);
    });

    testWidgets('opens each account screen for a signed-out person', (
      tester,
    ) async {
      await open(tester, AppRoutes.register);
      expect(find.byType(RegisterPage), findsOneWidget);

      await open(tester, AppRoutes.forgotPassword);
      expect(find.byType(ForgotPasswordPage), findsOneWidget);

      await open(tester, AppRoutes.resetPassword);
      expect(
        tester.widget<ResetPasswordPage>(find.byType(ResetPasswordPage)).email,
        isEmpty,
      );
    });

    testWidgets('holds a signed-in person while workspaces load', (
      tester,
    ) async {
      await tester.runAsync(backend.signedInBefore);

      await open(tester, AppRoutes.home, useKept: false);

      expect(find.byType(LoadingPage), findsOneWidget);
    });

    testWidgets('asks a person without a workspace to name one', (
      tester,
    ) async {
      await tester.runAsync(() => backend.signedInBefore(withWorkspace: false));
      final preferences = emptyPreferences(onboardingCompleted: true);
      final session = SessionCubit(
        authRepository: backend.auth,
        organizationsRepository: backend.organizations,
        preferencesRepository: preferences,
      );
      addTearDown(session.close);
      await tester.runAsync(session.loadWorkspaces);
      expect(session.state.stage, SessionStage.needsWorkspace);
      expect(
        redirectFor(
          welcomed: true,
          stage: session.state.stage,
          location: AppRoutes.home,
        ),
        AppRoutes.newWorkspace,
      );
    });

    testWidgets('does not show a ready person the entry screens', (
      tester,
    ) async {
      await tester.runAsync(backend.signedInBefore);

      await open(tester, AppRoutes.welcome);

      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('opens a screen inside an area directly', (tester) async {
      await tester.runAsync(backend.signedInBefore);

      await open(tester, AppRoutes.theme);

      expect(find.byType(ThemePage), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('opens email verification for a signed-in person', (
      tester,
    ) async {
      await tester.runAsync(backend.signedInBefore);

      await open(tester, AppRoutes.verifyEmail);

      expect(find.byType(VerifyEmailPage), findsOneWidget);
    });

    testWidgets('opens the add-printer screen and a printer by its id', (
      tester,
    ) async {
      await tester.runAsync(backend.signedInBefore);

      await open(tester, AppRoutes.addPrinter);
      expect(find.byType(AddPrinterPage), findsOneWidget);

      await open(tester, AppRoutes.printer('printer-7'));
      expect(
        tester
            .widget<PrinterDetailPage>(find.byType(PrinterDetailPage))
            .printerId,
        'printer-7',
      );
    });
  });
}
