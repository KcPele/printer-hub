import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/theme/theme.dart';

import '../../helpers/helpers.dart';

void main() {
  group('ThemePicker', () {
    Future<ThemeCubit> pump(WidgetTester tester) async {
      final preferences = emptyPreferences();
      final cubit = ThemeCubit(preferencesRepository: preferences);
      await tester.pumpApp(
        const Scaffold(body: ThemePicker()),
        themeCubit: cubit,
      );
      return cubit;
    }

    AppThemePreview previewOf(WidgetTester tester, String label) {
      return tester.widget<AppThemePreview>(
        find.widgetWithText(AppThemePreview, label),
      );
    }

    testWidgets('offers the three themes by name', (tester) async {
      await pump(tester);

      expect(find.byType(AppThemePreview), findsNWidgets(3));
      expect(previewOf(tester, 'Mint').theme, AppTheme.mint);
      expect(previewOf(tester, 'Indigo').theme, AppTheme.indigo);
      expect(previewOf(tester, 'Volt').theme, AppTheme.volt);
    });

    testWidgets('marks the theme in use', (tester) async {
      await pump(tester);

      expect(previewOf(tester, 'Mint').selected, isTrue);
      expect(previewOf(tester, 'Indigo').selected, isFalse);
      expect(previewOf(tester, 'Volt').selected, isFalse);
    });

    testWidgets('applies a theme as soon as it is tapped', (tester) async {
      final cubit = await pump(tester);

      await tester.tap(find.text('Volt'));
      await tester.pumpAndSettle();

      expect(cubit.state, AppThemeId.volt);
      expect(previewOf(tester, 'Volt').selected, isTrue);
      expect(
        Theme.of(tester.element(find.byType(ThemePicker)))
            .extension<AppColors>(),
        AppTheme.volt.light.colors,
      );
    });

    testWidgets('saves the choice', (tester) async {
      final preferences = emptyPreferences();
      await tester.pumpApp(
        const Scaffold(body: ThemePicker()),
        themeCubit: ThemeCubit(preferencesRepository: preferences),
      );

      await tester.tap(find.text('Indigo'));
      await tester.pumpAndSettle();

      verify(() => preferences.saveThemeName('indigo')).called(1);
    });
  });
}
