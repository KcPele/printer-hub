import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:preferences_repository/preferences_repository.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/home/home.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/settings/settings.dart';
import 'package:printerhub/theme/theme.dart';
import 'package:printerhub/welcome/welcome.dart';

import '../../helpers/helpers.dart';

void main() {
  group('createAppRouter', () {
    Future<GoRouter> pump(
      WidgetTester tester, {
      required bool welcomed,
      required String location,
    }) async {
      final preferences = emptyPreferences(onboardingCompleted: welcomed);
      final router = createAppRouter(
        preferencesRepository: preferences,
        initialLocation: location,
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        RepositoryProvider<PreferencesRepository>.value(
          value: preferences,
          child: BlocProvider(
            create: (_) => ThemeCubit(preferencesRepository: preferences),
            child: MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.volt.data(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('sends a new install to the welcome screens', (tester) async {
      await pump(tester, welcomed: false, location: AppRoutes.settings);

      expect(find.byType(WelcomePage), findsOneWidget);
      expect(find.byType(SettingsPage), findsNothing);
    });

    testWidgets('does not show the welcome screens twice', (tester) async {
      await pump(tester, welcomed: true, location: AppRoutes.welcome);

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(WelcomePage), findsNothing);
    });

    testWidgets('opens a screen inside an area directly', (tester) async {
      await pump(tester, welcomed: true, location: AppRoutes.theme);

      expect(find.byType(ThemePage), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });
}
