import 'package:app_ui/app_ui.dart';
import 'package:material_ui/material_ui.dart';

/// One thing to do: its sign, what it is, and a line about it.
class ToolTile extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Icon(icon, color: colors.onPrimary),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: textTheme.bodySmall?.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Tiles, two to a row, each row as tall as its taller tile.
class ToolGrid extends StatelessWidget {
  const new({required this.tiles, super.key});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var first = 0; first < tiles.length; first += 2) ...[
          if (first > 0) const SizedBox(height: AppSpacing.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[first]),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: first + 1 < tiles.length
                      ? tiles[first + 1]
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
