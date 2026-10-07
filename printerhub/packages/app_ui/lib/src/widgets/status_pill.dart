import 'package:app_ui/src/theme/app_semantic_colors.dart';
import 'package:app_ui/src/theme/app_spacing.dart';
import 'package:app_ui/src/theme/app_theme_context.dart';
import 'package:material_ui/material_ui.dart';

/// A small labelled status, such as "Online" or "Paper jam".
///
/// Its colours come from the status, never from the theme's brand colour, so
/// a warning looks like a warning in every theme.
class StatusPill extends StatelessWidget {
  const new({required this.status, required this.label, this.icon, super.key});

  final AppStatus status;
  final String label;

  /// Shown in place of the dot.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tone = context.semanticColors.status(status);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.container,
        borderRadius: context.shapes.chipRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + AppSpacing.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(icon, size: 14, color: tone.foreground)
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tone.foreground,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(dimension: AppSpacing.sm),
              ),
            const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelMedium?.copyWith(
                  color: tone.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
