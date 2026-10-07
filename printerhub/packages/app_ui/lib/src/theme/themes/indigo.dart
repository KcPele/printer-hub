import 'package:app_ui/src/fonts/app_fonts.dart';
import 'package:app_ui/src/theme/app_colors.dart';
import 'package:app_ui/src/theme/app_depth.dart';
import 'package:app_ui/src/theme/app_semantic_colors.dart';
import 'package:app_ui/src/theme/app_shapes.dart';
import 'package:app_ui/src/theme/app_theme_tokens.dart';
import 'package:material_ui/material_ui.dart';

const _indigo = Color(0xFF4856EB);
const _ink = Color(0xFF1C1E2B);

/// Indigo, light: indigo on a cool grey, large corners, soft shadows.
const AppThemeTokens indigoLight = AppThemeTokens(
  brightness: Brightness.light,
  fontFamily: AppFonts.plusJakartaSans,
  colors: AppColors(
    primary: _indigo,
    onPrimary: Color(0xFFFFFFFF),
    emphasis: _indigo,
    onEmphasis: Color(0xFFFFFFFF),
    accent: Color(0xFF3AC67C),
    onAccent: _ink,
    background: Color(0xFFEFF2FA),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF3F5FB),
    inverseSurface: _ink,
    onInverseSurface: Color(0xFFFFFFFF),
    text: _ink,
    textMuted: Color(0xFF5E6278),
    outline: Color(0xFFDCE1F0),
  ),
  semantic: AppSemanticColors.light,
  shapes: AppShapes(button: 20, card: 24, field: 20, chip: 14, sheet: 28),
  depth: AppDepth(
    cardShadow: [
      BoxShadow(color: Color(0x1A4856EB), blurRadius: 24, offset: Offset(0, 8)),
    ],
    cardBorder: BorderSide.none,
  ),
);
