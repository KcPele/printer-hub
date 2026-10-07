import 'package:material_ui/material_ui.dart';

/// A theme's brand and surface colours.
///
/// [primary] is a fill. It is not always readable as text: Volt's is yellow.
/// Use [emphasis] for brand-coloured text and icons on a light surface.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const new({
    required this.primary,
    required this.onPrimary,
    required this.emphasis,
    required this.onEmphasis,
    required this.accent,
    required this.onAccent,
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.text,
    required this.textMuted,
    required this.outline,
  });

  /// The brand fill: main buttons, selected states, highlights.
  final Color primary;

  /// Text and icons on [primary].
  final Color onPrimary;

  /// The brand colour that is readable as text or an icon on [background]
  /// and [surface].
  final Color emphasis;

  /// Text and icons on an [emphasis] fill.
  final Color onEmphasis;

  /// A second fill for the occasional contrast with [primary].
  final Color accent;

  /// Text and icons on [accent].
  final Color onAccent;

  /// Behind everything on a screen.
  final Color background;

  /// Cards and sheets.
  final Color surface;

  /// Insets on a surface: fields, tracks, quiet chips.
  final Color surfaceMuted;

  /// The dark block used for contrast against light surfaces.
  final Color inverseSurface;

  /// Text and icons on [inverseSurface].
  final Color onInverseSurface;

  /// Body text.
  final Color text;

  /// Supporting text.
  final Color textMuted;

  /// Borders and dividers.
  final Color outline;

  @override
  AppColors copyWith({
    Color? primary,
    Color? onPrimary,
    Color? emphasis,
    Color? onEmphasis,
    Color? accent,
    Color? onAccent,
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? inverseSurface,
    Color? onInverseSurface,
    Color? text,
    Color? textMuted,
    Color? outline,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      emphasis: emphasis ?? this.emphasis,
      onEmphasis: onEmphasis ?? this.onEmphasis,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      inverseSurface: inverseSurface ?? this.inverseSurface,
      onInverseSurface: onInverseSurface ?? this.onInverseSurface,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      outline: outline ?? this.outline,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      emphasis: Color.lerp(emphasis, other.emphasis, t)!,
      onEmphasis: Color.lerp(onEmphasis, other.onEmphasis, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      inverseSurface: Color.lerp(inverseSurface, other.inverseSurface, t)!,
      onInverseSurface: Color.lerp(
        onInverseSurface,
        other.onInverseSurface,
        t,
      )!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AppColors &&
            other.primary == primary &&
            other.onPrimary == onPrimary &&
            other.emphasis == emphasis &&
            other.onEmphasis == onEmphasis &&
            other.accent == accent &&
            other.onAccent == onAccent &&
            other.background == background &&
            other.surface == surface &&
            other.surfaceMuted == surfaceMuted &&
            other.inverseSurface == inverseSurface &&
            other.onInverseSurface == onInverseSurface &&
            other.text == text &&
            other.textMuted == textMuted &&
            other.outline == outline;
  }

  @override
  int get hashCode => Object.hash(
    primary,
    onPrimary,
    emphasis,
    onEmphasis,
    accent,
    onAccent,
    background,
    surface,
    surfaceMuted,
    inverseSurface,
    onInverseSurface,
    text,
    textMuted,
    outline,
  );
}
