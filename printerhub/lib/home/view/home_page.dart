import 'package:app_ui/app_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';

/// Home, as a person with no printers sees it: what the app is for and how
/// to begin.
class HomePage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appName)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.xxl,
        ),
        children: [
          AppCard(
            child: Column(
              children: [
                const AppIllustration(AppIllustrations.printer, width: 220),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.homeHeroTitle,
                  style: textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.homeHeroBody,
                  style: textTheme.bodyMedium?.copyWith(
                    color: context.colors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(l10n.homeStartTitle, style: textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              children: [
                _Step(
                  number: 1,
                  title: l10n.homeStepAddTitle,
                  body: l10n.homeStepAddBody,
                ),
                const SizedBox(height: AppSpacing.xl),
                _Step(
                  number: 2,
                  title: l10n.homeStepUseTitle,
                  body: l10n.homeStepUseBody,
                ),
                const SizedBox(height: AppSpacing.xl),
                _Step(
                  number: 3,
                  title: l10n.homeStepTrackTitle,
                  body: l10n.homeStepTrackBody,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const new({required this.number, required this.title, required this.body});

  final int number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.primary,
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(
            dimension: AppSpacing.xxl,
            child: Center(
              child: Text(
                '$number',
                style: textTheme.labelLarge?.copyWith(color: colors.onPrimary),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                body,
                style: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
