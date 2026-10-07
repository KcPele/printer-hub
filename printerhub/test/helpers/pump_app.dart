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

/// A preferences repository that remembers nothing between launches.
MockPreferencesRepository emptyPreferences({String? themeName}) {
  final repository = MockPreferencesRepository();
  when(() => repository.themeName).thenReturn(themeName);
  when(() => repository.saveThemeName(any())).thenAnswer((_) async {});
  return repository;
}

extension PumpApp on WidgetTester {
  /// Pumps [widget] with the app's theme, strings, and theme cubit.
  ///
  /// Pass [router] to check navigation without building other screens.
  Future<void> pumpApp(
    Widget widget, {
    ThemeCubit? themeCubit,
    GoRouter? router,
  }) {
    final cubit =
        themeCubit ?? ThemeCubit(preferencesRepository: emptyPreferences());

    return pumpWidget(
      BlocProvider.value(
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
    );
  }
}
