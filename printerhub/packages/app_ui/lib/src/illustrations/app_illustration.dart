import 'package:app_ui/src/theme/app_colors.dart';
import 'package:app_ui/src/theme/app_theme_context.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// The artwork drawn for the app.
enum AppIllustrations {
  /// A floor-standing multifunction printer.
  printer('printer'),

  /// A phone sending a document that comes out printed.
  phonePrint('phone_print'),

  /// A document behind a shield: it stays on the device.
  private('private');

  new(this.file);

  final String file;

  String get asset => 'assets/illustrations/$file.svg';
}

/// The colours an illustration file is drawn in.
///
/// Each one stands for a theme token and is replaced when the file is
/// rendered, so one file serves every theme. Any other colour in a file is
/// kept as drawn: that is how a status light stays green.
abstract final class IllustrationPalette {
  static const int primary = 0x4856EB;
  static const int onPrimary = 0xFEFEFF;
  static const int emphasis = 0x4856EC;
  static const int accent = 0x3AC67C;
  static const int ink = 0x1C1E2B;
  static const int onInk = 0xFDFDFF;
  static const int surface = 0xFFFFFF;
  static const int surfaceMuted = 0xEFF2FA;
  static const int outline = 0xDCE1F0;
  static const int textMuted = 0x5E6278;
}

/// Replaces the [IllustrationPalette] colours with a theme's.
@immutable
class IllustrationColorMapper extends ColorMapper {
  const new(this.colors);

  final AppColors colors;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    final themed = switch (color.toARGB32() & 0xFFFFFF) {
      IllustrationPalette.primary => colors.primary,
      IllustrationPalette.onPrimary => colors.onPrimary,
      IllustrationPalette.emphasis => colors.emphasis,
      IllustrationPalette.accent => colors.accent,
      IllustrationPalette.ink => colors.inverseSurface,
      IllustrationPalette.onInk => colors.onInverseSurface,
      IllustrationPalette.surface => colors.surface,
      IllustrationPalette.surfaceMuted => colors.surfaceMuted,
      IllustrationPalette.outline => colors.outline,
      IllustrationPalette.textMuted => colors.textMuted,
      _ => null,
    };
    return themed?.withValues(alpha: color.a) ?? color;
  }

  @override
  bool operator ==(Object other) {
    return other is IllustrationColorMapper && other.colors == colors;
  }

  @override
  int get hashCode => colors.hashCode;
}

/// Draws an illustration in the current theme's colours.
class AppIllustration extends StatelessWidget {
  const new(
    this.illustration, {
    this.width,
    this.height,
    this.semanticLabel,
    super.key,
  });

  final AppIllustrations illustration;
  final double? width;
  final double? height;

  /// What the picture shows, for screen readers. A picture without one is
  /// decoration and is hidden from them.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      illustration.asset,
      package: 'app_ui',
      width: width,
      height: height,
      colorMapper: IllustrationColorMapper(context.colors),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
