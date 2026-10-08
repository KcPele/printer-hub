import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/activity/cubit/activity_cubit.dart';
import 'package:printerhub/activity/job_recovery.dart';
import 'package:printerhub/activity/job_words.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/errors/error_messages.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/printers/cubit/printers_cubit.dart';
import 'package:printerhub/session/session.dart';

/// Job history: everything printed and scanned in the workspace, newest
/// first. Until there is something it explains what will appear here.
class ActivityPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final organizationId = context.select<SessionCubit, String?>(
      (cubit) => cubit.state.organization?.id,
    );
    // Signing out leaves this screen without a workspace for a moment.
    if (organizationId == null) return const Scaffold();

    return BlocProvider(
      // Another workspace has another history.
      key: ValueKey(organizationId),
      create: (context) {
        final cubit = ActivityCubit(
          jobsRepository: context.read<JobsRepository>(),
          recovery: context.read<JobRecovery>(),
          organizationId: organizationId,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const ActivityView(),
    );
  }
}

class ActivityView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ActivityCubit>();
    final state = context.watch<ActivityCubit>().state;
    final nothingYet =
        state.status == ActivityStatus.ready &&
        state.filter == ActivityFilter.all &&
        state.visible.isEmpty &&
        state.error == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navActivity),
        actions: [
          IconButton(
            tooltip: l10n.documentsTitle,
            onPressed: () => context.push(AppRoutes.documents),
            icon: const Icon(Icons.folder_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: switch (state.status) {
          ActivityStatus.failed => EmptyState(
            illustration: AppIllustrations.phonePrint,
            title: l10n.activityFailedTitle,
            message: errorMessage(l10n, state.error),
            action: FilledButton(
              onPressed: cubit.load,
              child: Text(l10n.loadingRetry),
            ),
          ),
          _ when nothingYet => EmptyState(
            illustration: AppIllustrations.phonePrint,
            title: l10n.activityEmptyTitle,
            message: l10n.activityEmptyBody,
          ),
          _ => RefreshIndicator(
            onRefresh: cubit.refresh,
            child: _Jobs(state: state),
          ),
        },
      ),
    );
  }
}

class _Jobs extends StatelessWidget {
  const new({required this.state});

  final ActivityState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ActivityCubit>();
    final visible = state.visible;
    final error = state.error;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xxl,
      ),
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final (filter, label) in [
              (ActivityFilter.all, l10n.activityFilterAll),
              (ActivityFilter.active, l10n.activityFilterActive),
              (ActivityFilter.done, l10n.activityFilterDone),
              (ActivityFilter.problems, l10n.activityFilterProblems),
            ])
              ChoiceChip(
                label: Text(label),
                selected: state.filter == filter,
                onSelected: (_) => cubit.show(filter),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (error != null) ...[
          AppNotice(message: errorMessage(l10n, error)),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (state.status == ActivityStatus.loading)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xxl),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (visible.isEmpty && error == null)
          AppCard(
            tone: AppCardTone.muted,
            child: Text(
              l10n.activityNoMatch,
              style: context.textTheme.bodyLarge,
            ),
          )
        else
          for (final job in visible) ...[
            _JobCard(job: job),
            const SizedBox(height: AppSpacing.md),
          ],
        if (state.next != null)
          Align(
            child: TextButton(
              onPressed: state.loadingMore ? null : cubit.more,
              child: Text(l10n.activityMore),
            ),
          ),
      ],
    );
  }
}

class _JobCard extends StatelessWidget {
  const new({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final colors = context.colors;
    final printer = context.select<PrintersCubit, String?>(
      (cubit) => cubit.state.printer(job.printerId)?.friendlyName,
    );
    final standing = JobWords.standing(l10n, job);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: () => context.push(AppRoutes.job(job.id), extra: job),
      child: Row(
        children: [
          Icon(JobWords.icon(job), color: colors.emphasis),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  JobWords.title(l10n, job),
                  style: textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  l10n.jobRowDetail(
                    printer ?? l10n.jobRemovedPrinter,
                    JobWords.when(context, job.submittedAt),
                  ),
                  style: textTheme.bodySmall?.copyWith(color: colors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    StatusPill(status: standing.status, label: standing.label),
                    if (job.waitingToSync)
                      StatusPill(
                        status: AppStatus.neutral,
                        label: l10n.jobOnPhoneOnly,
                        icon: Icons.cloud_off_outlined,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: colors.textMuted),
        ],
      ),
    );
  }
}
