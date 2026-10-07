import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences_repository/preferences_repository.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/theme/theme.dart';

class MockPreferencesRepository extends Mock implements PreferencesRepository;

class MockGoRouter extends Mock implements GoRouter;

/// Preferences held in memory for one test.
///
/// A new install by default: no theme chosen, welcome screens not seen.
MockPreferencesRepository emptyPreferences({
  String? themeName,
  bool onboardingCompleted = false,
}) {
  final repository = MockPreferencesRepository();
  var welcomed = onboardingCompleted;
  when(() => repository.themeName).thenReturn(themeName);
  when(() => repository.saveThemeName(any())).thenAnswer((_) async {});
  when(() => repository.onboardingCompleted).thenAnswer((_) => welcomed);
  when(repository.completeOnboarding).thenAnswer((_) async => welcomed = true);
  return repository;
}

/// A router that records where a screen asks to go.
MockGoRouter recordingRouter() {
  final router = MockGoRouter();
  when(() => router.push<Object?>(any())).thenAnswer((_) async => null);
  when(() => router.go(any())).thenReturn(null);
  return router;
}

extension PumpApp on WidgetTester {
  /// Pumps [widget] with the app's theme, strings, preferences, and theme
  /// cubit.
  ///
  /// Pass [router] to check navigation without building other screens.
  Future<void> pumpApp(
    Widget widget, {
    PreferencesRepository? preferencesRepository,
    ThemeCubit? themeCubit,
    GoRouter? router,
  }) {
    final preferences = preferencesRepository ?? emptyPreferences();
    final cubit = themeCubit ?? ThemeCubit(preferencesRepository: preferences);

    return pumpWidget(
      RepositoryProvider<PreferencesRepository>.value(
        value: preferences,
        child: BlocProvider.value(
          value: cubit,
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
}
