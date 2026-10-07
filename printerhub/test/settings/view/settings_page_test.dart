import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/settings/settings.dart';
import 'package:printerhub/theme/theme.dart';

import '../../helpers/helpers.dart';

void main() {
  group('SettingsPage', () {
    testWidgets('shows the theme in use', (tester) async {
      await tester.pumpApp(
        const SettingsPage(),
        preferencesRepository: emptyPreferences(themeName: 'indigo'),
      );

      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Indigo'), findsOneWidget);
    });

    testWidgets('shows the new theme as soon as it changes', (tester) async {
      final cubit = ThemeCubit(preferencesRepository: emptyPreferences());
      await tester.pumpApp(const SettingsPage(), themeCubit: cubit);
      expect(find.text('Volt'), findsOneWidget);

      await cubit.select(AppThemeId.mint);
      await tester.pumpAndSettle();

      expect(find.text('Mint'), findsOneWidget);
    });

    testWidgets('opens the theme screen', (tester) async {
      final router = recordingRouter();
      await tester.pumpApp(const SettingsPage(), router: router);

      await tester.tap(find.text('Theme'));

      verify(() => router.push<Object?>(AppRoutes.theme)).called(1);
    });

    testWidgets('opens the design gallery', (tester) async {
      final router = recordingRouter();
      await tester.pumpApp(const SettingsPage(), router: router);

      await tester.tap(find.text('Design gallery'));

      verify(() => router.push<Object?>(AppRoutes.gallery)).called(1);
    });
  });
}
