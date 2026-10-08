import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:organizations_repository/organizations_repository.dart';
import 'package:preferences_repository/preferences_repository.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/printers/printers.dart';
import 'package:printerhub/session/session.dart';
import 'package:printerhub/theme/theme.dart';
import 'package:printers_repository/printers_repository.dart';

import 'test_backend.dart';

class MockPreferencesRepository extends Mock implements PreferencesRepository;

class MockGoRouter extends Mock implements GoRouter;

/// Preferences held in memory for one test.
///
/// A new install by default: no theme chosen, welcome screens not seen.
MockPreferencesRepository emptyPreferences({
  String? themeName,
  bool onboardingCompleted = false,
  String? activeOrganizationId,
}) {
  final repository = MockPreferencesRepository();
  var theme = themeName;
  var welcomed = onboardingCompleted;
  var organization = activeOrganizationId;
  when(() => repository.themeName).thenAnswer((_) => theme);
  when(() => repository.saveThemeName(any())).thenAnswer((invocation) async {
    theme = invocation.positionalArguments.single as String;
  });
  when(() => repository.onboardingCompleted).thenAnswer((_) => welcomed);
  when(repository.completeOnboarding).thenAnswer((_) async => welcomed = true);
  when(() => repository.activeOrganizationId).thenAnswer((_) => organization);
  when(() => repository.saveActiveOrganizationId(any()))
      .thenAnswer((invocation) async {
        organization = invocation.positionalArguments.single as String?;
      });
  return repository;
}

/// A router that records where a screen asks to go.
MockGoRouter recordingRouter() {
  final router = MockGoRouter();
  when(() => router.push<Object?>(any(), extra: any(named: 'extra')))
      .thenAnswer((_) async => null);
  when(() => router.go(any())).thenReturn(null);
  when(router.pop).thenReturn(null);
  return router;
}

extension PumpApp on WidgetTester {
  /// Pumps [widget] with what every screen can rely on: the theme, the
  /// strings, the repositories, and the theme and session cubits.
  ///
  /// The repositories talk to [backend]. Pass [router] to check navigation
  /// without building other screens.
  Future<void> pumpApp(
    Widget widget, {
    PreferencesRepository? preferencesRepository,
    ThemeCubit? themeCubit,
    TestBackend? backend,
    SessionCubit? sessionCubit,
    PrintersCubit? printersCubit,
    GoRouter? router,
  }) async {
    final preferences = preferencesRepository ?? emptyPreferences();
    final api = backend ?? TestBackend();
    if (backend == null) addTearDown(api.close);
    final theme = themeCubit ?? ThemeCubit(preferencesRepository: preferences);
    final session =
        sessionCubit ??
        SessionCubit(
          authRepository: api.auth,
          organizationsRepository: api.organizations,
          preferencesRepository: preferences,
          keptOrganizations: await api.organizations.kept(),
        );
    if (sessionCubit == null) addTearDown(session.close);
    final printers =
        printersCubit ??
        PrintersCubit(
          printersRepository: api.printers,
          organizationId: session.state.organization?.id,
          organizationChanges: session.stream
              .map((state) => state.organization?.id)
              .distinct(),
        );
    if (printersCubit == null) addTearDown(printers.close);

    await pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<PreferencesRepository>.value(value: preferences),
          RepositoryProvider<AuthRepository>.value(value: api.auth),
          RepositoryProvider<OrganizationsRepository>.value(
            value: api.organizations,
          ),
          RepositoryProvider<PrintersRepository>.value(value: api.printers),
          RepositoryProvider<PrinterFinders>.value(value: api.finders),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: theme),
            BlocProvider.value(value: session),
            BlocProvider.value(value: printers),
          ],
          child: BlocBuilder<ThemeCubit, AppThemeId>(
            builder: (context, theme) => MaterialApp(
              theme: AppTheme.of(theme).data(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: router == null
                  ? widget
                  : InheritedGoRouter(goRouter: router, child: widget),
            ),
          ),
        ),
      ),
    );
  }

  /// Pumps the whole app on top of [backend].
  Future<void> pumpWholeApp(
    TestBackend backend,
    PreferencesRepository preferences,
  ) async {
    await pumpWidget(
      App(
        preferencesRepository: preferences,
        authRepository: backend.auth,
        organizationsRepository: backend.organizations,
        printersRepository: backend.printers,
        finders: backend.finders,
        keptOrganizations: await backend.organizations.kept(),
      ),
    );
    await pumpAndSettle();
  }

  /// Types [text] into the field labelled [label].
  Future<void> fill(String label, String text) {
    return enterText(find.widgetWithText(TextFormField, label), text);
  }
}
