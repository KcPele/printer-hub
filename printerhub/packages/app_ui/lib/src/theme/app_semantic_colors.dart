import 'package:material_ui/material_ui.dart';

/// What a status is telling the user.
enum AppStatus {
  /// Working as expected: online, ready, completed.
  success,

  /// Needs attention soon: low toner, paper nearly out.
  warning,

  /// Stopped: jam, door open, failed job.
  error,

  /// In progress or informational: printing, scanning, syncing.
  info,

  /// No signal either way: offline, unknown, cancelled.
  neutral,
}

/// A printer's consumable colours.
enum TonerColor { cyan, magenta, yellow, black }

/// The pair of colours a status is drawn in.
@immutable
class StatusTone {
  const new({required this.foreground, required this.container});

  factory lerp(StatusTone a, StatusTone b, double t) {
    return StatusTone(
      foreground: Color.lerp(a.foreground, b.foreground, t)!,
      container: Color.lerp(a.container, b.container, t)!,
    );
  }

  /// Text, icons, and dots. Readable on [container] and on a theme's
  /// background and surface.
  final Color foreground;

  /// The tinted fill behind [foreground].
  final Color container;
}

/// Colours whose meaning is the same in every theme.
///
/// They are separate from a theme's brand colours on purpose: a warning is
/// amber in Volt, Indigo, and Mint, and cyan toner is always cyan.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const new({
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.neutral,
    required this.tonerCyan,
    required this.tonerMagenta,
    required this.tonerYellow,
    required this.tonerBlack,
  });

  /// The values every light theme uses.
  static const AppSemanticColors light = AppSemanticColors(
    success: StatusTone(
      foreground: Color(0xFF147A45),
      container: Color(0xFFE3F5EA),
    ),
    warning: StatusTone(
      foreground: Color(0xFF8A5200),
      container: Color(0xFFFFF1D6),
    ),
    error: StatusTone(
      foreground: Color(0xFFB3261E),
      container: Color(0xFFFDE7E5),
    ),
    info: StatusTone(
      foreground: Color(0xFF1D5FBF),
      container: Color(0xFFE4EEFC),
    ),
    neutral: StatusTone(
      foreground: Color(0xFF5F6368),
      container: Color(0xFFECEDEF),
    ),
    tonerCyan: Color(0xFF00AEEF),
    tonerMagenta: Color(0xFFEC008C),
    tonerYellow: Color(0xFFFFD400),
    tonerBlack: Color(0xFF231F20),
  );

  final StatusTone success;
  final StatusTone warning;
  final StatusTone error;
  final StatusTone info;
  final StatusTone neutral;
  final Color tonerCyan;
  final Color tonerMagenta;
  final Color tonerYellow;
  final Color tonerBlack;

  /// The tone for [status].
  StatusTone status(AppStatus status) => switch (status) {
    AppStatus.success => success,
    AppStatus.warning => warning,
    AppStatus.error => error,
    AppStatus.info => info,
    AppStatus.neutral => neutral,
  };

  /// The colour for [toner].
  Color toner(TonerColor toner) => switch (toner) {
    TonerColor.cyan => tonerCyan,
    TonerColor.magenta => tonerMagenta,
    TonerColor.yellow => tonerYellow,
    TonerColor.black => tonerBlack,
  };

  @override
  AppSemanticColors copyWith({
    StatusTone? success,
    StatusTone? warning,
    StatusTone? error,
    StatusTone? info,
    StatusTone? neutral,
    Color? tonerCyan,
    Color? tonerMagenta,
    Color? tonerYellow,
    Color? tonerBlack,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      neutral: neutral ?? this.neutral,
      tonerCyan: tonerCyan ?? this.tonerCyan,
      tonerMagenta: tonerMagenta ?? this.tonerMagenta,
      tonerYellow: tonerYellow ?? this.tonerYellow,
      tonerBlack: tonerBlack ?? this.tonerBlack,
    );
  }

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other == null) return this;
    return AppSemanticColors(
      success: StatusTone.lerp(success, other.success, t),
      warning: StatusTone.lerp(warning, other.warning, t),
      error: StatusTone.lerp(error, other.error, t),
      info: StatusTone.lerp(info, other.info, t),
      neutral: StatusTone.lerp(neutral, other.neutral, t),
      tonerCyan: Color.lerp(tonerCyan, other.tonerCyan, t)!,
      tonerMagenta: Color.lerp(tonerMagenta, other.tonerMagenta, t)!,
      tonerYellow: Color.lerp(tonerYellow, other.tonerYellow, t)!,
      tonerBlack: Color.lerp(tonerBlack, other.tonerBlack, t)!,
    );
  }
}
