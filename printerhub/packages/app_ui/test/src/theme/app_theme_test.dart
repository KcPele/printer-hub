import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('AppTheme', () {
    test('finds each theme by its id', () {
      for (final id in AppThemeId.values) {
        expect(AppTheme.of(id).id, id);
      }
      expect(AppTheme.all.map((theme) => theme.id), AppThemeId.values);
    });

    test('has a light and a dark variant of every theme', () {
      for (final theme in AppTheme.all) {
        expect(theme.hasDark, isTrue);
        expect(theme.tokens(Brightness.light), theme.light);
        expect(theme.tokens(Brightness.dark), theme.dark);
        expect(theme.light.brightness, Brightness.light);
        expect(theme.dark!.brightness, Brightness.dark);
        // A skin changes colour, never shape or type.
        expect(theme.dark!.shapes, theme.light.shapes);
        expect(theme.dark!.fontFamily, theme.light.fontFamily);
        expect(theme.dark!.semantic, AppSemanticColors.dark);
      }
    });

    test('answers with light tokens for a theme with no dark variant', () {
      final theme = AppTheme(id: AppThemeId.mint, light: AppTheme.mint.light);

      expect(theme.hasDark, isFalse);
      expect(theme.tokens(Brightness.dark), theme.light);
    });

    test('uses the dark tokens of a theme that defines them', () {
      const dark = AppThemeTokens(
        brightness: Brightness.dark,
        fontFamily: AppFonts.manrope,
        colors: AppColors(
          primary: Color(0xFF46D7B7),
          onPrimary: Color(0xFF0B3B32),
          emphasis: Color(0xFF46D7B7),
          onEmphasis: Color(0xFF0B3B32),
          accent: Color(0xFFFB7746),
          onAccent: Color(0xFF1A1A1A),
          background: Color(0xFF101010),
          surface: Color(0xFF1A1A1A),
          surfaceMuted: Color(0xFF242424),
          inverseSurface: Color(0xFFFFFFFF),
          onInverseSurface: Color(0xFF1A1A1A),
          text: Color(0xFFFFFFFF),
          textMuted: Color(0xFFB0B0B0),
          outline: Color(0xFF333333),
        ),
        semantic: AppSemanticColors.light,
        shapes: AppShapes(button: 12, card: 16, field: 12, chip: 8, sheet: 16),
        depth: AppDepth.flat,
      );
      final theme = AppTheme(
        id: AppThemeId.mint,
        light: AppTheme.mint.light,
        dark: dark,
      );

      expect(theme.hasDark, isTrue);
      expect(theme.tokens(Brightness.dark), dark);
      expect(theme.data(Brightness.dark).brightness, Brightness.dark);
      expect(theme.data().brightness, Brightness.light);
    });
  });

  group('the Material theme', () {
    for (final (theme, brightness) in [
      for (final theme in AppTheme.all)
        for (final brightness in Brightness.values) (theme, brightness),
    ]) {
      final tokens = theme.tokens(brightness);
      final colors = tokens.colors;

      group('${theme.id.name}, ${brightness.name}', () {
        late ThemeData data;

        setUp(() => data = theme.data(brightness));

        test('is as light or dark as asked', () {
          expect(data.brightness, brightness);
          expect(data.colorScheme.brightness, brightness);
        });

        test('carries every token set', () {
          expect(data.extension<AppColors>(), colors);
          expect(data.extension<AppSemanticColors>(), tokens.semantic);
          expect(data.extension<AppShapes>(), tokens.shapes);
          expect(data.extension<AppDepth>(), tokens.depth);
        });

        test('uses the theme font and text colour', () {
          expect(data.textTheme.bodyLarge?.fontFamily, tokens.fontFamily);
          expect(data.textTheme.bodyLarge?.color, colors.text);
          expect(data.scaffoldBackgroundColor, colors.background);
        });

        test('draws text-like controls in the readable brand colour', () {
          expect(data.colorScheme.primary, colors.emphasis);
          expect(data.colorScheme.primaryContainer, colors.primary);
        });

        test('fills the main button with the brand colour', () {
          final style = data.filledButtonTheme.style!;

          expect(style.backgroundColor?.resolve({}), colors.primary);
          expect(style.foregroundColor?.resolve({}), colors.onPrimary);
        });

        test('marks the selected navigation item', () {
          final bar = data.navigationBarTheme;
          const selected = {WidgetState.selected};

          expect(bar.indicatorColor, colors.primary);
          expect(bar.iconTheme?.resolve(selected)?.color, colors.onPrimary);
          expect(bar.iconTheme?.resolve({})?.color, colors.textMuted);
          expect(bar.labelTextStyle?.resolve(selected)?.color, colors.text);
          expect(bar.labelTextStyle?.resolve({})?.color, colors.textMuted);
        });

        test('fills a switch that is on with the brand colour', () {
          final theme = data.switchTheme;
          const selected = {WidgetState.selected};

          expect(theme.trackColor?.resolve(selected), colors.primary);
          expect(theme.trackColor?.resolve({}), colors.surfaceMuted);
          expect(theme.thumbColor?.resolve(selected), colors.onPrimary);
          expect(theme.thumbColor?.resolve({}), colors.textMuted);
          expect(theme.trackOutlineColor?.resolve(selected), colors.primary);
          expect(theme.trackOutlineColor?.resolve({}), colors.outline);
        });
      });
    }
  });
}
