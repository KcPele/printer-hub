import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:organizations_repository/organizations_repository.dart';
import 'package:printerhub/errors/error_messages.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/session/session.dart';
import 'package:printerhub/workspace/cubit/members_cubit.dart';
import 'package:printerhub/workspace/workspace_words.dart';

/// The people in the workspace: who they are, what they may do, and who
/// has been invited.
class MembersPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final organization = context.read<SessionCubit>().state.organization;
    if (organization == null) return const Scaffold();

    return BlocProvider(
      key: ValueKey(organization.id),
      create: (context) {
        final cubit = MembersCubit(
          organizationsRepository: context.read<OrganizationsRepository>(),
          organizationId: organization.id,
          canManage: organization.canManage,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: MembersView(canManage: organization.canManage),
    );
  }
}

class MembersView extends StatelessWidget {
  const new({required this.canManage, super.key});

  final bool canManage;

  Future<void> _invite(BuildContext context) async {
    final cubit = context.read<MembersCubit>();
    final wanted = await showDialog<({String email, String role})>(
      context: context,
      builder: (_) => const _InviteDialog(),
    );
    if (wanted != null) {
      await cubit.invite(email: wanted.email, role: wanted.role);
    }
  }

  Future<void> _remove(BuildContext context, Member member) async {
    final l10n = context.l10n;
    final cubit = context.read<MembersCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.membersRemoveTitle(member.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.workspaceCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.membersRemove),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.remove(member);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final cubit = context.read<MembersCubit>();
    final state = context.watch<MembersCubit>().state;
    final me = context.select<SessionCubit, String?>(
      (cubit) => cubit.state.user?.id,
    );
    final error = state.error;
    final dates = MaterialLocalizations.of(context);

    return BlocListener<MembersCubit, MembersState>(
      listenWhen: (previous, current) =>
          current.sent != null && current.sent != previous.sent,
      listener: (context, state) => showDialog<void>(
        context: context,
        builder: (_) => _CodeDialog(invitation: state.sent!),
      ),
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.membersTitle)),
        body: SafeArea(
          child: switch (state.status) {
            MembersStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            MembersStatus.failed => EmptyState(
              illustration: AppIllustrations.createAccount,
              title: l10n.membersFailedTitle,
              message: errorMessage(l10n, error),
              action: FilledButton(
                onPressed: cubit.load,
                child: Text(l10n.loadingRetry),
              ),
            ),
            MembersStatus.ready => ListView(
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
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    children: [
                      for (final member in state.members)
                        ListTile(
                          title: Text(
                            member.userId == me
                                ? '${member.name} (${l10n.membersYou})'
                                : member.name,
                          ),
                          subtitle: Text(
                            '${member.email}\n'
                            '${WorkspaceWords.role(l10n, member.role)}',
                          ),
                          isThreeLine: true,
                          // An owner is not changed from here, and nobody
                          // changes themselves.
                          trailing:
                              canManage &&
                                  member.userId != me &&
                                  member.role != 'owner'
                              ? PopupMenuButton<String>(
                                  enabled: !state.busy,
                                  onSelected: (chosen) => chosen == _removeKey
                                      ? _remove(context, member)
                                      : cubit.changeRole(member, chosen),
                                  itemBuilder: (_) => [
                                    for (final role
                                        in WorkspaceWords.assignable)
                                      CheckedPopupMenuItem(
                                        value: role,
                                        checked: role == member.role,
                                        child: Text(
                                          WorkspaceWords.role(l10n, role),
                                        ),
                                      ),
                                    const PopupMenuDivider(),
                                    PopupMenuItem(
                                      value: _removeKey,
                                      child: Text(l10n.membersRemove),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                    ],
                  ),
                ),
                if (state.invitations.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Text(l10n.membersWaiting, style: textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Column(
                      children: [
                        for (final invitation in state.invitations)
                          ListTile(
                            title: Text(invitation.email),
                            subtitle: Text(
                              l10n.membersInvitedAs(
                                WorkspaceWords.role(l10n, invitation.role),
                                dates.formatMediumDate(
                                  invitation.expiresAt.toLocal(),
                                ),
                              ),
                            ),
                            trailing: IconButton(
                              tooltip: l10n.membersRevoke,
                              onPressed: state.busy
                                  ? null
                                  : () => cubit.revoke(invitation),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (canManage) ...[
                  const SizedBox(height: AppSpacing.xl),
                  AppSubmitButton(
                    label: l10n.membersInvite,
                    loading: state.busy,
                    onPressed: () => _invite(context),
                  ),
                ],
              ],
            ),
          },
        ),
      ),
    );
  }
}

/// Stands for "remove" among the roles of a member's menu.
const String _removeKey = '-';

/// Asks who to invite, and as what.
class _InviteDialog extends StatefulWidget {
  const new();

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _email = TextEditingController();
  String _role = 'user';

  static final RegExp _address = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final email = _email.text.trim();

    return AlertDialog(
      title: Text(l10n.membersInvite),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _email,
              autofocus: true,
              autocorrect: false,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: l10n.membersInviteEmail),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              initialValue: _role,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.membersInviteRole),
              items: [
                for (final role in WorkspaceWords.assignable)
                  DropdownMenuItem(
                    value: role,
                    child: Text(WorkspaceWords.role(l10n, role)),
                  ),
              ],
              onChanged: (role) => setState(() => _role = role ?? _role),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.workspaceCancel),
        ),
        TextButton(
          onPressed: _address.hasMatch(email)
              ? () => Navigator.of(context).pop((email: email, role: _role))
              : null,
          child: Text(l10n.membersInviteSend),
        ),
      ],
    );
  }
}

/// Shows the code of an invitation just made, the one time it is known.
class _CodeDialog extends StatelessWidget {
  const new({required this.invitation});

  final Invitation invitation;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final code = invitation.code ?? '';

    return AlertDialog(
      title: Text(l10n.membersCodeTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.membersCodeBody(invitation.email)),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            tone: AppCardTone.muted,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SelectableText(
              code,
              style: context.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await Clipboard.setData(ClipboardData(text: code));
            messenger.showSnackBar(
              SnackBar(content: Text(l10n.membersCodeCopied)),
            );
          },
          child: Text(l10n.membersCodeCopy),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.membersCodeDone),
        ),
      ],
    );
  }
}
