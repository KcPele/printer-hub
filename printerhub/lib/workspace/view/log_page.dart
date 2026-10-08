import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:organizations_repository/organizations_repository.dart';
import 'package:printerhub/activity/job_words.dart';
import 'package:printerhub/errors/error_messages.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/session/session.dart';
import 'package:printerhub/workspace/cubit/log_cubit.dart';
import 'package:printerhub/workspace/cubit/members_cubit.dart';
import 'package:printerhub/workspace/workspace_words.dart';

/// What has been done in the workspace: printers added, people invited,
/// settings changed, and by whom.
class WorkspaceLogPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final organization = context.read<SessionCubit>().state.organization;
    if (organization == null) return const Scaffold();

    return MultiBlocProvider(
      key: ValueKey(organization.id),
      providers: [
        BlocProvider(
          create: (context) {
            final cubit = LogCubit(
              organizationsRepository: context.read<OrganizationsRepository>(),
              organizationId: organization.id,
            );
            unawaited(cubit.load());
            return cubit;
          },
        ),
        BlocProvider(
          // The members, to put a name to who did each thing.
          lazy: false,
          create: (context) {
            final cubit = MembersCubit(
              organizationsRepository: context.read<OrganizationsRepository>(),
              organizationId: organization.id,
              canManage: false,
            );
            unawaited(cubit.load());
            return cubit;
          },
        ),
      ],
      child: const WorkspaceLogView(),
    );
  }
}

class WorkspaceLogView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final colors = context.colors;
    final cubit = context.read<LogCubit>();
    final state = context.watch<LogCubit>().state;
    final names = context.select<MembersCubit, Map<String, String>>(
      (cubit) => {
        for (final member in cubit.state.members) member.userId: member.name,
      },
    );
    final error = state.error;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.logTitle)),
      body: SafeArea(
        child: switch (state.status) {
          LogStatus.loading => const Center(child: CircularProgressIndicator()),
          LogStatus.failed => EmptyState(
            illustration: AppIllustrations.private,
            title: l10n.logFailedTitle,
            message: errorMessage(l10n, error),
            action: FilledButton(
              onPressed: cubit.load,
              child: Text(l10n.loadingRetry),
            ),
          ),
          LogStatus.ready when state.actions.isEmpty => EmptyState(
            illustration: AppIllustrations.private,
            title: l10n.logTitle,
            message: l10n.logEmpty,
          ),
          LogStatus.ready => RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                AppSpacing.xxl,
              ),
              children: [
                if (error != null) ...[
                  AppNotice(message: errorMessage(l10n, error)),
                  const SizedBox(height: AppSpacing.md),
                ],
                for (final logged in state.actions) ...[
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [
                            WorkspaceWords.action(l10n, logged),
                            ?WorkspaceWords.about(logged),
                          ].join(': '),
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          l10n.logBy(switch (logged.actorUserId) {
                            null => l10n.logSystem,
                            final id => names[id] ?? l10n.logSomeone,
                          }, JobWords.when(context, logged.at)),
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                        if (!logged.succeeded) ...[
                          const SizedBox(height: AppSpacing.sm),
                          StatusPill(
                            status: AppStatus.error,
                            label: l10n.logFailed,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (state.next != null)
                  Align(
                    child: TextButton(
                      onPressed: state.loadingMore ? null : cubit.more,
                      child: Text(l10n.logMore),
                    ),
                  ),
              ],
            ),
          ),
        },
      ),
    );
  }
}
