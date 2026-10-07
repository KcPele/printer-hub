import 'package:app_ui/src/theme/app_colors.dart';
import 'package:app_ui/src/theme/app_depth.dart';
import 'package:app_ui/src/theme/app_semantic_colors.dart';
import 'package:app_ui/src/theme/app_shapes.dart';
import 'package:material_ui/material_ui.dart';

/// Everything that makes up one theme at one brightness.
@immutable
class AppThemeTokens {
  const new({
    required this.brightness,
    required this.fontFamily,
    required this.colors,
    required this.semantic,
    required this.shapes,
    required this.depth,
  });

  final Brightness brightness;
  final String fontFamily;
  final AppColors colors;
  final AppSemanticColors semantic;
  final AppShapes shapes;
  final AppDepth depth;
}
