import 'package:app_ui/src/theme/app_semantic_colors.dart';
import 'package:app_ui/src/theme/app_spacing.dart';
import 'package:app_ui/src/theme/app_theme_context.dart';
import 'package:material_ui/material_ui.dart';

/// A sentence the user should not miss: an error, a warning, a confirmation.
class AppNotice extends StatelessWidget {
  const new({
    required this.message,
    this.status = AppStatus.error,
    this.action,
    super.key,
  });

  final String message;
  final AppStatus status;

  /// Something to do about it, usually a text button.
  final Widget? action;

  static IconData _iconFor(AppStatus status) => switch (status) {
    AppStatus.success => Icons.check_circle_outline,
    AppStatus.warning => Icons.warning_amber_rounded,
    AppStatus.error => Icons.error_outline,
    AppStatus.info || AppStatus.neutral => Icons.info_outline,
  };

  @override
  Widget build(BuildContext context) {
    final tone = context.semanticColors.status(status);

    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tone.container,
          borderRadius: context.shapes.chipRadius.resolve(
            Directionality.of(context),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_iconFor(status), size: 20, color: tone.foreground),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: tone.foreground,
                      ),
                    ),
                    ?action,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
