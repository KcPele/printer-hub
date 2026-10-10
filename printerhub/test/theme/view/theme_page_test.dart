import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/theme/theme.dart';

import '../../helpers/helpers.dart';

void main() {
  group('ThemePage', () {
    testWidgets('explains the choice and shows the picker', (tester) async {
      await tester.pumpApp(const ThemePage());

      expect(find.text('Theme'), findsOneWidget);
      expect(
        find.text('Choose how PrinterHub looks. It changes straight away.'),
        findsOneWidget,
      );
      expect(find.byType(ThemePicker), findsOneWidget);
    });

    testWidgets('looks as the phone does until told otherwise, in every '
        'theme', (tester) async {
      for (final theme in AppTheme.all) {
        final preferences = emptyPreferences(themeName: theme.id.name);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        await tester.pumpApp(
          const ThemePage(),
          preferencesRepository: preferences,
        );
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.byType(ThemePicker))).brightness,
          Brightness.dark,
        );
        expect(
          tester.element(find.byType(ThemePicker)).colors.background,
          theme.dark!.colors.background,
        );

        tester.platformDispatcher.platformBrightnessTestValue =
            Brightness.light;
        await tester.pumpAndSettle();
        expect(
          tester.element(find.byType(ThemePicker)).colors.background,
          theme.light.colors.background,
        );
      }
    });

    testWidgets('goes dark, or light, when that is chosen, and keeps the '
        'choice', (tester) async {
      final preferences = emptyPreferences();
      await tester.pumpApp(
        const ThemePage(),
        preferencesRepository: preferences,
      );
      expect(find.text('Light or dark'), findsOneWidget);
      Brightness shown() =>
          Theme.of(tester.element(find.byType(ThemePicker))).brightness;
      expect(shown(), Brightness.light);

      await tester.ensureVisible(find.text('Dark'));
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(shown(), Brightness.dark);
      expect(preferences.brightnessName, 'dark');

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(shown(), Brightness.light);

      await tester.tap(find.text('As my phone'));
      await tester.pumpAndSettle();
      expect(preferences.brightnessName, 'system');
    });
  });
}
