import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/activity/cubit/job_cubit.dart';
import 'package:printerhub/activity/job_words.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/errors/error_messages.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/print/print_words.dart';
import 'package:printerhub/printers/cubit/printers_cubit.dart';
import 'package:printerhub/session/session.dart';

/// One job from the history: what was asked for, and what happened.
class JobPage extends StatelessWidget {
  const new({required this.jobId, this.known, super.key});

  final String jobId;

  /// The job as the list had it, shown while the rest is read.
  final Job? known;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = JobCubit(
          jobsRepository: context.read<JobsRepository>(),
          organizationId: context.read<SessionCubit>().state.organization!.id,
          jobId: jobId,
          known: known,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const JobView(),
    );
  }
}

class JobView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<JobCubit>();
    final state = context.watch<JobCubit>().state;
    final job = state.job;

    return BlocListener<JobCubit, JobState>(
      listenWhen: (previous, current) =>
          current.cancelled && !previous.cancelled,
      listener: (context, state) =>
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.jobCancelled))),
      child: Scaffold(
        appBar: AppBar(
          title: job == null ? null : Text(JobWords.kind(l10n, job)),
        ),
        body: SafeArea(
          child: job == null
              ? state.status == JobLoadStatus.failed
                    ? EmptyState(
                        illustration: AppIllustrations.phonePrint,
                        title: l10n.jobFailedTitle,
                        message: errorMessage(l10n, state.error),
                        action: FilledButton(
                          onPressed: cubit.load,
                          child: Text(l10n.loadingRetry),
                        ),
                      )
                    : const Center(child: CircularProgressIndicator())
              : _Job(state: state, job: job),
        ),
      ),
    );
  }
}

class _Job extends StatelessWidget {
  const new({required this.state, required this.job});

  final JobState state;
  final Job job;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final colors = context.colors;
    final cubit = context.read<JobCubit>();
    final printer = context.select<PrintersCubit, String?>(
      (cubit) => cubit.state.printer(job.printerId)?.friendlyName,
    );
    final standing = JobWords.standing(l10n, job);
    final failure = job.status == 'failed'
        ? JobWords.failure(l10n, code: job.errorCode, said: job.errorMessage)
        : null;
    final choices = job.print;
    final pages = job.pageCount;
    final error = state.error;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xxl,
      ),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(JobWords.title(l10n, job), style: textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              StatusPill(status: standing.status, label: standing.label),
              const SizedBox(height: AppSpacing.lg),
              _Fact(
                label: l10n.jobPrinter,
                value: printer ?? l10n.jobRemovedPrinter,
              ),
              _Fact(
                label: l10n.jobStarted,
                value: JobWords.when(context, job.submittedAt),
              ),
            ],
          ),
        ),
        if (failure != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppNotice(message: failure),
        ],
        if (job.waitingToSync) ...[
          const SizedBox(height: AppSpacing.md),
          AppNotice(status: AppStatus.info, message: l10n.jobNotSent),
        ],
        if (job.fallbackOccurred) ...[
          const SizedBox(height: AppSpacing.md),
          AppNotice(status: AppStatus.info, message: l10n.jobFallback),
        ],
        if (job.retryOfJobId != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppNotice(status: AppStatus.info, message: l10n.jobRetryOf),
        ],
        if (error != null && state.status != JobLoadStatus.failed) ...[
          const SizedBox(height: AppSpacing.md),
          AppNotice(message: errorMessage(l10n, error)),
        ],
        if (choices != null) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.jobSectionAsked, style: textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in [
                  if (pages != null) l10n.printPageCount(pages),
                  l10n.jobCopies(choices.copies),
                  PrintWords.sides(l10n, choices.sides),
                  if (choices.color == 'monochrome')
                    l10n.jobColorOff
                  else if (choices.color == 'color')
                    l10n.jobColorOn,
                  if (choices.mediaSize != null)
                    PrintWords.paper(choices.mediaSize!),
                  if (choices.tray != null)
                    PrintWords.tray(l10n, choices.tray!),
                  if (choices.quality != null)
                    PrintWords.quality(l10n, choices.quality!),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Text(line, style: textTheme.bodyLarge),
                  ),
              ],
            ),
          ),
        ],
        if (state.status == JobLoadStatus.loading)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xxl),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (state.status == JobLoadStatus.failed) ...[
          const SizedBox(height: AppSpacing.md),
          AppNotice(
            message: errorMessage(l10n, error),
            action: TextButton(
              onPressed: cubit.load,
              child: Text(l10n.loadingRetry),
            ),
          ),
        ],
        if (state.events.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.jobSectionHistory, style: textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              children: [
                for (final event in state.events)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            [
                              JobWords.step(l10n, event.status),
                              ?JobWords.failure(
                                l10n,
                                code: event.errorCode,
                                said: event.errorMessage,
                              ),
                            ].join('\n'),
                            style: textTheme.bodyLarge,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          JobWords.when(context, event.occurredAt),
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        if (job.kind == 'print' && job.isFinished && printer != null)
          AppSubmitButton(
            label: l10n.jobPrintAgain,
            onPressed: () => context.go(
              AppRoutes.printOn(job.printerId),
              extra: job.canRetry ? job : null,
            ),
          ),
        if (!job.isFinished && !job.waitingToSync) ...[
          OutlinedButton(
            onPressed: state.cancelling ? null : cubit.cancel,
            child: Text(l10n.jobCancel),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.jobCancelNote,
            style: textTheme.bodySmall?.copyWith(color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const new({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: context.colors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: textTheme.bodyLarge,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
