import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';

/// A theme's corner radii.
@immutable
class AppShapes extends ThemeExtension<AppShapes> {
  const new({
    required this.button,
    required this.card,
    required this.field,
    required this.chip,
    required this.sheet,
  });

  /// A radius large enough to turn any control into a pill.
  static const double pill = 999;

  final double button;
  final double card;
  final double field;
  final double chip;
  final double sheet;

  BorderRadius get buttonRadius => BorderRadius.circular(button);
  BorderRadius get cardRadius => BorderRadius.circular(card);
  BorderRadius get fieldRadius => BorderRadius.circular(field);
  BorderRadius get chipRadius => BorderRadius.circular(chip);

  /// Sheets are rounded at the top only.
  BorderRadius get sheetRadius =>
      BorderRadius.vertical(top: Radius.circular(sheet));

  @override
  AppShapes copyWith({
    double? button,
    double? card,
    double? field,
    double? chip,
    double? sheet,
  }) {
    return AppShapes(
      button: button ?? this.button,
      card: card ?? this.card,
      field: field ?? this.field,
      chip: chip ?? this.chip,
      sheet: sheet ?? this.sheet,
    );
  }

  @override
  AppShapes lerp(AppShapes? other, double t) {
    if (other == null) return this;
    return AppShapes(
      button: lerpDouble(button, other.button, t)!,
      card: lerpDouble(card, other.card, t)!,
      field: lerpDouble(field, other.field, t)!,
      chip: lerpDouble(chip, other.chip, t)!,
      sheet: lerpDouble(sheet, other.sheet, t)!,
    );
  }
}
