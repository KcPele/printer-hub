import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:organizations_repository/organizations_repository.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/errors/error_messages.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/session/session.dart';
import 'package:printerhub/workspace/cubit/invitations_cubit.dart';
import 'package:printerhub/workspace/workspace_words.dart';

/// The invitations the signed-in person has been sent, and joining a
/// workspace by one of them or by a code.
class InvitationsPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = InvitationsCubit(
          organizationsRepository: context.read<OrganizationsRepository>(),
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const InvitationsView(),
    );
  }
}

class InvitationsView extends StatefulWidget {
  const new({super.key});

  @override
  State<InvitationsView> createState() => _InvitationsViewState();
}

class _InvitationsViewState extends State<InvitationsView> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final cubit = context.read<InvitationsCubit>();
    final state = context.watch<InvitationsCubit>().state;
    final error = state.error;

    return BlocListener<InvitationsCubit, InvitationsState>(
      listenWhen: (previous, current) =>
          current.joined != null && current.joined != previous.joined,
      listener: (context, state) async {
        final session = context.read<SessionCubit>();
        final joined = state.joined!;
        _code.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.invitationsJoined(joined.name))),
        );
        // The new workspace joins the others, and is the one in use.
        await session.loadWorkspaces();
        await session.selectWorkspace(joined);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.invitationsTitle)),
        body: SafeArea(
          child: switch (state.status) {
            InvitationsStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            InvitationsStatus.failed => EmptyState(
              illustration: AppIllustrations.createAccount,
              title: l10n.invitationsFailedTitle,
              message: errorMessage(l10n, error),
              action: FilledButton(
                onPressed: cubit.load,
                child: Text(l10n.loadingRetry),
              ),
            ),
            InvitationsStatus.ready => ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                AppSpacing.xxl,
              ),
              children: [
                if (state.needsVerifiedEmail)
                  AppNotice(
                    status: AppStatus.warning,
                    message: l10n.invitationsNeedVerified,
                    action: TextButton(
                      onPressed: () => context.push(AppRoutes.verifyEmail),
                      child: Text(l10n.verifyTitle),
                    ),
                  )
                else if (error != null)
                  AppNotice(message: errorMessage(l10n, error))
                else if (state.invitations.isEmpty)
                  AppCard(
                    tone: AppCardTone.muted,
                    child: Text(
                      l10n.invitationsEmpty,
                      style: textTheme.bodyLarge,
                    ),
                  ),
                for (final invitation in state.invitations) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        Icon(
                          Icons.apartment_outlined,
                          color: context.colors.emphasis,
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                invitation.organizationName,
                                style: textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                l10n.invitationsAs(
                                  WorkspaceWords.role(l10n, invitation.role),
                                ),
                                style: textTheme.bodySmall?.copyWith(
                                  color: context.colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton(
                          onPressed: state.busy
                              ? null
                              : () => cubit.accept(invitation),
                          child: Text(l10n.invitationsAccept),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Text(l10n.invitationsCodeTitle, style: textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _code,
                  enabled: !state.busy,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.invitationsCodeLabel,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: state.busy || _code.text.trim().isEmpty
                      ? null
                      : () => cubit.acceptCode(_code.text),
                  child: Text(l10n.invitationsCodeJoin),
                ),
              ],
            ),
          },
        ),
      ),
    );
  }
}
