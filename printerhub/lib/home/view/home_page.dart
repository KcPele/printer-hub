import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/notifications/notifications.dart';
import 'package:printerhub/printers/printers.dart';
import 'package:printerhub/session/session.dart';
import 'package:printers_repository/printers_repository.dart';

/// Home: the workspace's printers at a glance, or, before there are any,
/// what the app is for and how to begin.
class HomePage extends StatelessWidget {
  const new({super.key});

  /// How many printers Home shows before "See all".
  static const int _shown = 3;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final printers = context.select<PrintersCubit, List<PrinterRead>>(
      (cubit) => cubit.state.printers,
    );
    final unread = context.watch<UnreadCubit>().state;
    final needsVerification = context.select<SessionCubit, bool>(
      (cubit) => cubit.state.user?.emailVerified == false,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appName),
        actions: [
          IconButton(
            tooltip: l10n.notificationsTitle,
            onPressed: () => context.push(AppRoutes.notifications),
            icon: Badge.count(
              count: unread,
              isLabelVisible: unread > 0,
              child: const Icon(Icons.notifications_none),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.xxl,
        ),
        children: [
          if (needsVerification) ...[
            AppNotice(
              status: AppStatus.warning,
              message: l10n.verifyBanner,
              action: TextButton(
                onPressed: () => context.push(AppRoutes.verifyEmail),
                child: Text(l10n.verifyTitle),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (printers.isEmpty)
            const _Introduction()
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(l10n.homePrinters, style: textTheme.titleLarge),
                ),
                TextButton(
                  onPressed: () => context.go(AppRoutes.printers),
                  child: Text(l10n.homeSeeAll),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final printer in printers.take(_shown)) ...[
              PrinterCard(
                printer: printer,
                onTap: () => context.go(AppRoutes.printer(printer.id)),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ],
      ),
    );
  }
}

/// What a person with no printers sees: what the app is for and how to
/// begin.
class _Introduction extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
