import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:organizations_repository/organizations_repository.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/errors/error_messages.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/session/session.dart';
import 'package:printerhub/workspace/cubit/workspace_cubit.dart';

/// The workspace in use: its name, its rules, and leaving or deleting it.
class WorkspacePage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionCubit>().state;
    final organization = session.organization;
    // Leaving the last workspace takes this screen away a moment later.
    if (organization == null) return const Scaffold();

    return BlocProvider(
      key: ValueKey(organization.id),
      create: (context) {
        final cubit = WorkspaceCubit(
          organizationsRepository: context.read<OrganizationsRepository>(),
          organizationId: organization.id,
          userId: session.user!.id,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const WorkspaceView(),
    );
  }
}

class WorkspaceView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<WorkspaceCubit>();
    final state = context.watch<WorkspaceCubit>().state;
    final workspace = state.workspace;

    return BlocListener<WorkspaceCubit, WorkspaceState>(
      listenWhen: (previous, current) =>
          current.done != null && previous.done != current.done,
      listener: (context, state) async {
        final name = state.workspace!.organization.name;
        final messenger = ScaffoldMessenger.of(context);
        // A workspace that is gone has no screen of its own to stay on.
        final router = state.done == WorkspaceDone.saved
            ? null
            : GoRouter.of(context);
        final session = context.read<SessionCubit>();
        messenger.showSnackBar(
          SnackBar(
            content: Text(switch (state.done!) {
              WorkspaceDone.saved => l10n.workspaceSaved,
              WorkspaceDone.left => l10n.workspaceLeft(name),
              WorkspaceDone.deleted => l10n.workspaceDeleted(name),
            }),
          ),
        );
        // The session learns the new name, or that the workspace is gone.
        await session.loadWorkspaces();
        router?.go(AppRoutes.settings);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.workspaceTitle)),
        body: SafeArea(
          child: workspace == null
              ? state.status == WorkspaceStatus.failed
                    ? EmptyState(
                        illustration: AppIllustrations.printer,
                        title: l10n.workspaceFailedTitle,
                        message: errorMessage(l10n, state.error),
                        action: FilledButton(
                          onPressed: cubit.load,
                          child: Text(l10n.loadingRetry),
                        ),
                      )
                    : const Center(child: CircularProgressIndicator())
              : _Workspace(
                  // A saved workspace fills the form afresh.
                  key: ValueKey(workspace),
                  workspace: workspace,
                  state: state,
                ),
        ),
      ),
    );
  }
}

class _Workspace extends StatefulWidget {
  const new({required this.workspace, required this.state, super.key});

  final Workspace workspace;
  final WorkspaceState state;

  @override
  State<_Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<_Workspace> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.workspace.organization.name,
  );
  late final _maxCopies = TextEditingController(
    text: widget.workspace.policy.maxCopiesPerJob?.toString() ?? '',
  );
  late bool _cloud = widget.workspace.policy.cloudDocuments;

  @override
  void dispose() {
    _name.dispose();
    _maxCopies.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final copies = int.tryParse(_maxCopies.text.trim());
    await context.read<WorkspaceCubit>().save(
      name: _name.text.trim(),
      policy: widget.workspace.policy.copyWith(
        maxCopiesPerJob: () => copies,
        cloudDocuments: _cloud,
      ),
    );
  }

  Future<void> _confirm({
    required String title,
    required String body,
    required String confirm,
    required Future<void> Function() then,
  }) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.workspaceCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await then();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final cubit = context.read<WorkspaceCubit>();
    final organization = widget.workspace.organization;
    final policy = widget.workspace.policy;
    final busy = widget.state.busy;
    final error = widget.state.error;
    final danger = context.semanticColors.error.foreground;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xxl,
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (organization.canManage) ...[
              TextFormField(
                controller: _name,
                enabled: !busy,
                maxLength: 200,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l10n.workspaceName),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? l10n.workspaceNameRequired
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.workspaceRulesTitle, style: textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _maxCopies,
                      enabled: !busy,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: l10n.workspaceMaxCopies,
                        hintText: l10n.workspaceMaxCopiesHint,
                      ),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty) return null;
                        final copies = int.tryParse(text) ?? 0;
                        return copies < 1 || copies > 9999
                            ? l10n.workspaceMaxCopiesInvalid
                            : null;
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.workspaceCloud),
                      subtitle: Text(l10n.workspaceCloudBody),
                      value: _cloud,
                      onChanged: busy
                          ? null
                          : (on) => setState(() => _cloud = on),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Text(organization.name, style: textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.workspaceRulesTitle, style: textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Rule(
                      label: l10n.workspaceMaxCopies,
                      value:
                          policy.maxCopiesPerJob?.toString() ??
                          l10n.workspaceNoLimit,
                    ),
                    _Rule(
                      label: l10n.workspaceCloud,
                      value: policy.cloudDocuments
                          ? l10n.workspaceYes
                          : l10n.workspaceNo,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.workspaceRulesReadOnly,
                      style: textTheme.bodySmall?.copyWith(
                        color: context.colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppNotice(message: errorMessage(l10n, error)),
            ],
            if (organization.canManage) ...[
              const SizedBox(height: AppSpacing.xl),
              AppSubmitButton(
                label: l10n.workspaceSave,
                loading: busy,
                onPressed: _save,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(l10n.workspaceLog),
                  subtitle: Text(l10n.workspaceLogSubtitle),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: context.colors.textMuted,
                  ),
                  onTap: () => context.push(AppRoutes.workspaceLog),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: danger),
              onPressed: busy
                  ? null
                  : () => _confirm(
                      title: l10n.workspaceLeaveTitle(organization.name),
                      body: l10n.workspaceLeaveBody,
                      confirm: l10n.workspaceLeaveConfirm,
                      then: cubit.leave,
                    ),
              child: Text(l10n.workspaceLeave),
            ),
            if (organization.role == 'owner')
              TextButton(
                style: TextButton.styleFrom(foregroundColor: danger),
                onPressed: busy
                    ? null
                    : () => _confirm(
                        title: l10n.workspaceDeleteTitle(organization.name),
                        body: l10n.workspaceDeleteBody,
                        confirm: l10n.workspaceDeleteConfirm,
                        then: cubit.delete,
                      ),
                child: Text(l10n.workspaceDelete),
              ),
          ],
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const new({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: context.textTheme.bodyLarge)),
          const SizedBox(width: AppSpacing.md),
          Text(value, style: context.textTheme.titleMedium),
        ],
      ),
    );
  }
}
