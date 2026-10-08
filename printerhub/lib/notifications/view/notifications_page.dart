import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:printerhub/activity/job_words.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/errors/error_messages.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/notifications/cubit/notifications_cubit.dart';
import 'package:printerhub/session/session.dart';

/// What the account has been told: jobs that finished or failed, scans
/// that are ready, invitations.
class NotificationsPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = NotificationsCubit(
          notificationsRepository: context.read<NotificationsRepository>(),
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const NotificationsView(),
    );
  }
}

class NotificationsView extends StatelessWidget {
  const new({super.key});

  /// Marks [notification] read and goes to what it is about, in the
  /// workspace it happened in.
  Future<void> _open(BuildContext context, AppNotification notification) async {
    final router = GoRouter.of(context);
    final session = context.read<SessionCubit>();
    unawaited(context.read<NotificationsCubit>().read(notification));

    final jobId = notification.jobId;
    if (jobId == null) return;
    final workspace = session.state.organizations
        .where((one) => one.id == notification.organizationId)
        .firstOrNull;
    if (workspace == null) return;
    if (workspace.id != session.state.organization?.id) {
      await session.selectWorkspace(workspace);
    }
    router.go(AppRoutes.job(jobId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<NotificationsCubit>();
    final state = context.watch<NotificationsCubit>().state;
    final error = state.error;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
        actions: [
          if (state.hasUnread)
            TextButton(
              onPressed: cubit.readAll,
              child: Text(l10n.notificationsReadAll),
            ),
        ],
      ),
      body: SafeArea(
        child: switch (state.status) {
          NotificationsStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          NotificationsStatus.failed => EmptyState(
            illustration: AppIllustrations.phonePrint,
            title: l10n.notificationsFailedTitle,
            message: errorMessage(l10n, error),
            action: FilledButton(
              onPressed: cubit.load,
              child: Text(l10n.loadingRetry),
            ),
          ),
          NotificationsStatus.ready when state.notifications.isEmpty =>
            EmptyState(
              illustration: AppIllustrations.phonePrint,
              title: l10n.notificationsEmptyTitle,
              message: l10n.notificationsEmptyBody,
            ),
          NotificationsStatus.ready => RefreshIndicator(
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
                for (final notification in state.notifications) ...[
                  _NotificationCard(
                    notification: notification,
                    onTap: () => _open(context, notification),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (state.next != null)
                  Align(
                    child: TextButton(
                      onPressed: state.loadingMore ? null : cubit.more,
                      child: Text(l10n.notificationsMore),
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

class _NotificationCard extends StatelessWidget {
  const new({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  static (IconData, AppStatus) _look(String type) => switch (type) {
    'job.completed' => (Icons.check_circle_outline, AppStatus.success),
    'job.failed' => (Icons.error_outline, AppStatus.error),
    'job.cancelled' => (Icons.cancel_outlined, AppStatus.neutral),
    'scan.ready' => (Icons.document_scanner_outlined, AppStatus.info),
    'organization.invitation' => (Icons.mail_outline, AppStatus.info),
    _ => (Icons.notifications_none, AppStatus.neutral),
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final colors = context.colors;
    final (icon, status) = _look(notification.type);
    final tone = context.semanticColors.status(status);

    return AppCard(
      tone: notification.isRead ? AppCardTone.muted : AppCardTone.surface,
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone.foreground),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification.title, style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xxs),
                Text(notification.body, style: textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  JobWords.when(context, notification.createdAt),
                  style: textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          if (!notification.isRead) ...[
            const SizedBox(width: AppSpacing.sm),
            Semantics(
              label: context.l10n.notificationUnread,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.emphasis,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(dimension: AppSpacing.sm),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
