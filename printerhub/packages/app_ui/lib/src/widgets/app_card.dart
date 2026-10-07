import 'package:app_ui/src/theme/app_spacing.dart';
import 'package:app_ui/src/theme/app_theme_context.dart';
import 'package:material_ui/material_ui.dart';

/// What an [AppCard] is filled with.
enum AppCardTone {
  /// The theme's card surface. This is the only tone that carries the
  /// theme's shadow or border.
  surface,

  /// A quiet inset.
  muted,

  /// The dark block.
  inverse,

  /// The brand fill.
  primary,
}

/// A rounded container in the theme's shape and depth.
///
/// Inside a tone other than [AppCardTone.surface], the theme's text and icon
/// colours are replaced with ones that read on that tone, so a child uses
/// `context.colors.text` and the text theme as it would anywhere else.
class AppCard extends StatelessWidget {
  const new({
    required this.child,
    this.tone = AppCardTone.surface,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.onTap,
    super.key,
  });

  /// How far supporting text is blended toward the fill on [tone].
  ///
  /// A brand fill leaves less room than the dark block before text stops
  /// meeting AA contrast, so it is muted less.
  static double mutedBlend(AppCardTone tone) => switch (tone) {
    AppCardTone.primary => 0.08,
    _ => 0.28,
  };

  final Widget child;
  final AppCardTone tone;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final shapes = context.shapes;
    final depth = context.depth;

    final (fill, foreground) = switch (tone) {
      AppCardTone.surface => (colors.surface, colors.text),
      AppCardTone.muted => (colors.surfaceMuted, colors.text),
      AppCardTone.inverse => (colors.inverseSurface, colors.onInverseSurface),
      AppCardTone.primary => (colors.primary, colors.onPrimary),
    };
    final raised = tone == AppCardTone.surface;
    final hasBorder = raised && depth.cardBorder.style != BorderStyle.none;

    Widget content = Padding(padding: padding, child: child);
    if (tone == AppCardTone.inverse || tone == AppCardTone.primary) {
      content = Theme(
        data: theme.copyWith(
          textTheme: theme.textTheme.apply(
            bodyColor: foreground,
            displayColor: foreground,
          ),
          iconTheme: theme.iconTheme.copyWith(color: foreground),
          extensions: [
            colors.copyWith(
              surface: fill,
              text: foreground,
              textMuted: Color.lerp(foreground, fill, mutedBlend(tone)),
            ),
            context.semanticColors,
            shapes,
            depth,
          ],
        ),
        child: content,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: shapes.cardRadius,
        boxShadow: raised ? depth.cardShadow : null,
        border: hasBorder ? Border.fromBorderSide(depth.cardBorder) : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: shapes.cardRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: content),
      ),
    );
  }
}
