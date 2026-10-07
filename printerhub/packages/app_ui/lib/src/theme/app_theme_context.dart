import 'package:app_ui/src/theme/app_colors.dart';
import 'package:app_ui/src/theme/app_depth.dart';
import 'package:app_ui/src/theme/app_semantic_colors.dart';
import 'package:app_ui/src/theme/app_shapes.dart';
import 'package:material_ui/material_ui.dart';

/// Reads the current theme's tokens.
///
/// These are the only source of colour, shape, and depth for a widget.
extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;

  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>()!;

  AppShapes get shapes => Theme.of(this).extension<AppShapes>()!;

  AppDepth get depth => Theme.of(this).extension<AppDepth>()!;

  TextTheme get textTheme => Theme.of(this).textTheme;
}
