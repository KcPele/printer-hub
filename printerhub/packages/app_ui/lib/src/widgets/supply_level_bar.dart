import 'package:app_ui/src/theme/app_semantic_colors.dart';
import 'package:app_ui/src/theme/app_spacing.dart';
import 'package:app_ui/src/theme/app_theme_context.dart';
import 'package:material_ui/material_ui.dart';

/// How much of a consumable is left.
class SupplyLevelBar extends StatelessWidget {
  const new({
    required this.toner,
    required this.label,
    required this.valueLabel,
    required this.level,
    super.key,
  });

  /// The supply's colour. Null for a supply that has none, such as a drum
  /// or a waste box.
  final TonerColor? toner;

  /// The supply's name, for example "Cyan".
  final String label;

  /// The level in words, for example "72%" or "Unknown".
  final String valueLabel;

  /// Between 0 and 1, or null when the printer does not report it.
  final double? level;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final fill = (level ?? 0).clamp(0.0, 1.0);

    return Semantics(
      label: '$label, $valueLabel',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: textTheme.labelMedium)),
              Text(
                valueLabel,
                style: textTheme.labelMedium?.copyWith(color: colors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.xs),
            child: SizedBox(
              height: AppSpacing.sm,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: colors.surfaceMuted),
                  FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: fill,
                    child: ColoredBox(
                      color: toner == null
                          ? colors.textMuted
                          : context.semanticColors.toner(toner!),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
