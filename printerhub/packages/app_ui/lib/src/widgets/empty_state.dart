import 'package:app_ui/src/illustrations/app_illustration.dart';
import 'package:app_ui/src/theme/app_spacing.dart';
import 'package:app_ui/src/theme/app_theme_context.dart';
import 'package:material_ui/material_ui.dart';

/// What a screen shows when it has nothing to list yet.
class EmptyState extends StatelessWidget {
  const new({
    required this.illustration,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final AppIllustrations illustration;
  final String title;
  final String message;

  /// The one thing to do next, usually a button.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIllustration(illustration, width: 200),
            const SizedBox(height: AppSpacing.xl),
            Text(
              title,
              style: textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: textTheme.bodyLarge?.copyWith(
                color: context.colors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
