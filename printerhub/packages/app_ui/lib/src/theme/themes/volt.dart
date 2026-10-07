import 'package:app_ui/src/fonts/app_fonts.dart';
import 'package:app_ui/src/theme/app_colors.dart';
import 'package:app_ui/src/theme/app_depth.dart';
import 'package:app_ui/src/theme/app_semantic_colors.dart';
import 'package:app_ui/src/theme/app_shapes.dart';
import 'package:app_ui/src/theme/app_theme_tokens.dart';
import 'package:material_ui/material_ui.dart';

const _charcoal = Color(0xFF212121);
const _yellow = Color(0xFFFFFF1E);

/// Volt, light: charcoal and yellow, pills and circles, flat.
const AppThemeTokens voltLight = AppThemeTokens(
  brightness: Brightness.light,
  fontFamily: AppFonts.lufga,
  colors: AppColors(
    primary: _yellow,
    onPrimary: _charcoal,
    // Yellow cannot be read on a light surface, so Volt's emphasis is its
    // charcoal, with yellow on top.
    emphasis: _charcoal,
    onEmphasis: _yellow,
    accent: _charcoal,
    onAccent: _yellow,
    background: Color(0xFFEEEEEE),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF4F4F4),
    inverseSurface: _charcoal,
    onInverseSurface: Color(0xFFFFFFFF),
    text: _charcoal,
    textMuted: Color(0xFF5C5C5C),
    outline: Color(0xFFD6D6D6),
  ),
  semantic: AppSemanticColors.light,
  shapes: AppShapes(
    button: AppShapes.pill,
    card: 32,
    field: AppShapes.pill,
    chip: AppShapes.pill,
    sheet: 36,
  ),
  depth: AppDepth.flat,
);
