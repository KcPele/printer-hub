import 'package:app_ui/src/theme/app_spacing.dart';
import 'package:app_ui/src/theme/app_theme_context.dart';
import 'package:material_ui/material_ui.dart';

/// A row of dots showing which page of a few is in view.
class AppPageIndicator extends StatelessWidget {
  const new({required this.count, required this.index, super.key});

  final int count;
  final int index;

  static const double _dot = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              width: i == index ? _dot * 3 : _dot,
              height: _dot,
              decoration: BoxDecoration(
                color: i == index ? colors.emphasis : colors.outline,
                borderRadius: BorderRadius.circular(_dot / 2),
              ),
            ),
        ],
      ),
    );
  }
}
