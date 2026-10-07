import 'dart:math' as math;

import 'package:app_ui/src/theme/app_spacing.dart';
import 'package:app_ui/src/theme/app_theme.dart';
import 'package:app_ui/src/theme/app_theme_context.dart';
import 'package:app_ui/src/theme/app_theme_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// A miniature of a theme, for choosing between them.
///
/// The miniature is drawn in [theme]'s own tokens. The label and the
/// selection ring are drawn in the theme that is currently applied.
class AppThemePreview extends StatelessWidget {
  const new({
    required this.theme,
    required this.label,
    required this.selected,
    this.onTap,
    super.key,
  });

  final AppTheme theme;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  static const double _frameRadius = 20;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = theme.tokens(Theme.of(context).brightness);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_frameRadius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_frameRadius),
                border: Border.all(
                  color: selected ? colors.emphasis : colors.outline,
                  width: selected ? 2 : 1,
                ),
              ),
              child: _Miniature(tokens: tokens),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Icon(Icons.check_circle, size: 16, color: colors.emphasis),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Miniature extends StatelessWidget {
  const new({required this.tokens});

  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final colors = tokens.colors;
    final shapes = tokens.shapes;
    final depth = tokens.depth;
    final hasBorder = depth.cardBorder.style != BorderStyle.none;

    // The miniature is about a fifth of a phone screen, so its corners are
    // the theme's corners at that scale, capped where a pill is reached.
    double scaled(double radius, double cap) => math.min(radius / 2.5, cap);

    return AspectRatio(
      aspectRatio: 0.78,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm + AppSpacing.xxs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Bar(color: colors.text, widthFactor: 0.55, height: 6),
              const SizedBox(height: AppSpacing.xs),
              _Bar(color: colors.textMuted, widthFactor: 0.35, height: 4),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(
                      scaled(shapes.card, 12),
                    ),
                    boxShadow: depth.cardShadow,
                    border: hasBorder
                        ? Border.fromBorderSide(depth.cardBorder)
                        : null,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.bottomStart,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.inverseSurface,
                          borderRadius: BorderRadius.circular(
                            scaled(shapes.chip, 4),
                          ),
                        ),
                        child: const SizedBox(width: 22, height: 8),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(scaled(shapes.button, 8)),
                ),
                child: const SizedBox(height: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const new({
    required this.color,
    required this.widthFactor,
    required this.height,
  });

  final Color color;
  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: widthFactor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: SizedBox(height: height),
      ),
    );
  }
}
