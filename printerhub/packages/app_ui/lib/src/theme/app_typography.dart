import 'package:material_ui/material_ui.dart';

/// The type scale. Sizes and weights are the same in every theme; the font
/// family and colour come from the theme.
abstract final class AppTypography {
  static TextTheme textTheme({
    required String fontFamily,
    required Color color,
  }) {
    TextStyle style(
      double size,
      FontWeight weight, {
      required double height,
      double spacing = 0,
    }) {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        // The bundled fonts are variable fonts. Naming the weight axis makes
        // every weight render as drawn instead of being synthesised.
        fontVariations: [FontVariation.weight(weight.value.toDouble())],
        height: height,
        letterSpacing: spacing,
        color: color,
      );
    }

    return TextTheme(
      displayLarge: style(48, FontWeight.w700, height: 1.1, spacing: -1),
      displayMedium: style(40, FontWeight.w700, height: 1.1, spacing: -0.8),
      displaySmall: style(32, FontWeight.w700, height: 1.15, spacing: -0.5),
      headlineLarge: style(28, FontWeight.w700, height: 1.2, spacing: -0.4),
      headlineMedium: style(24, FontWeight.w700, height: 1.25, spacing: -0.2),
      headlineSmall: style(20, FontWeight.w600, height: 1.3),
      titleLarge: style(18, FontWeight.w600, height: 1.3),
      titleMedium: style(16, FontWeight.w600, height: 1.35),
      titleSmall: style(14, FontWeight.w600, height: 1.4),
      bodyLarge: style(16, FontWeight.w400, height: 1.5),
      bodyMedium: style(14, FontWeight.w400, height: 1.45),
      bodySmall: style(12, FontWeight.w400, height: 1.4),
      labelLarge: style(15, FontWeight.w600, height: 1.3),
      labelMedium: style(13, FontWeight.w600, height: 1.3),
      labelSmall: style(11, FontWeight.w600, height: 1.3, spacing: 0.4),
    );
  }
}
