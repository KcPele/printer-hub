import 'package:app_ui/src/fonts/app_fonts.dart';
import 'package:app_ui/src/theme/app_colors.dart';
import 'package:app_ui/src/theme/app_depth.dart';
import 'package:app_ui/src/theme/app_semantic_colors.dart';
import 'package:app_ui/src/theme/app_shapes.dart';
import 'package:app_ui/src/theme/app_theme_tokens.dart';
import 'package:material_ui/material_ui.dart';

const _mint = Color(0xFF46D7B7);
const _ink = Color(0xFF1A1A1A);

/// Mint, light: mint on white, medium corners, hairline borders.
const AppThemeTokens mintLight = AppThemeTokens(
  brightness: Brightness.light,
  fontFamily: AppFonts.manrope,
  colors: AppColors(
    primary: _mint,
    // White on this mint is 1.8:1. Deep teal reads clearly and keeps the hue.
    onPrimary: Color(0xFF0B3B32),
    emphasis: Color(0xFF0A7461),
    onEmphasis: Color(0xFFFFFFFF),
    accent: Color(0xFFFB7746),
    onAccent: _ink,
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFF7F7F7),
    surfaceMuted: Color(0xFFEFEFEF),
    inverseSurface: _ink,
    onInverseSurface: Color(0xFFFFFFFF),
    text: _ink,
    textMuted: Color(0xFF5F5F5F),
    outline: Color(0xFFE2E2E2),
  ),
  semantic: AppSemanticColors.light,
  shapes: AppShapes(button: 12, card: 16, field: 12, chip: 8, sheet: 16),
  depth: AppDepth(
    cardShadow: [],
    cardBorder: BorderSide(color: Color(0xFFE2E2E2)),
  ),
);
