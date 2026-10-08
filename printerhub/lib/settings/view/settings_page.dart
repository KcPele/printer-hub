import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:organizations_repository/organizations_repository.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/session/session.dart';
import 'package:printerhub/theme/theme.dart';
import 'package:printerhub/workspace/workspace_words.dart';

class SettingsPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.select<ThemeCubit, AppThemeId>(
      (cubit) => cubit.state,
    );
    final session = context.watch<SessionCubit>().state;
    final user = session.user;
    final organization = session.organization;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.xxl,
        ),
        children: [
          if (user != null) ...[
            _Section(
              title: l10n.settingsAccount,
              children: [
                _Entry(
                  icon: Icons.person_outline,
                  title: user.name,
                  subtitle: user.email,
                  onTap: () => context.push(AppRoutes.profile),
                ),
                if (!user.emailVerified)
                  _Entry(
                    icon: Icons.mark_email_unread_outlined,
                    title: l10n.settingsVerifyEmail,
                    subtitle: l10n.settingsVerifyEmailSubtitle,
                    onTap: () => context.push(AppRoutes.verifyEmail),
                  ),
                if (organization != null)
                  _Entry(
                    icon: Icons.apartment_outlined,
                    title: l10n.settingsWorkspace,
                    subtitle: organization.name,
                    // Nothing to choose between with a single workspace.
                    onTap: session.organizations.length < 2
                        ? null
                        : () => _chooseWorkspace(context, session),
                  ),
                _Entry(
                  icon: Icons.lock_outline,
                  title: l10n.settingsPassword,
                  onTap: () => context.push(AppRoutes.changePassword),
                ),
                _Entry(
                  icon: Icons.devices_outlined,
                  title: l10n.settingsDevices,
                  subtitle: l10n.settingsDevicesSubtitle,
                  onTap: () => context.push(AppRoutes.devices),
                ),
                _Entry(
                  icon: Icons.logout,
                  title: l10n.settingsSignOut,
                  onTap: () => context.read<SessionCubit>().signOut(),
                ),
                _Entry(
                  icon: Icons.delete_outline,
                  title: l10n.settingsDeleteAccount,
                  onTap: () => context.push(AppRoutes.deleteAccount),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            _Section(
              title: l10n.settingsTeam,
              children: [
                if (organization != null) ...[
                  _Entry(
                    icon: Icons.tune,
                    title: l10n.settingsWorkspaceRules,
                    subtitle: WorkspaceWords.role(l10n, organization.role),
                    onTap: () => context.push(AppRoutes.workspace),
                  ),
                  _Entry(
                    icon: Icons.group_outlined,
                    title: l10n.settingsPeople,
                    subtitle: l10n.settingsPeopleSubtitle,
                    onTap: () => context.push(AppRoutes.members),
                  ),
                ],
                _Entry(
                  icon: Icons.mail_outline,
                  title: l10n.settingsInvitations,
                  subtitle: l10n.settingsInvitationsSubtitle,
                  onTap: () => context.push(AppRoutes.invitations),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          _Section(
            title: l10n.settingsAppearance,
            children: [
              _Entry(
                icon: Icons.palette_outlined,
                title: l10n.themeTitle,
                subtitle: theme.label(l10n),
                onTap: () => context.push(AppRoutes.theme),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _Section(
            title: l10n.settingsDeveloper,
            children: [
              _Entry(
                icon: Icons.widgets_outlined,
                title: l10n.galleryTitle,
                subtitle: l10n.settingsGallerySubtitle,
                onTap: () => context.push(AppRoutes.gallery),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _chooseWorkspace(BuildContext context, SessionState session) {
    final cubit = context.read<SessionCubit>();

    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final Organization option in session.organizations)
              ListTile(
                title: Text(option.name),
                trailing: option == session.organization
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(cubit.selectWorkspace(option));
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const new({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            title,
            style: context.textTheme.labelLarge?.copyWith(
              color: context.colors.textMuted,
            ),
          ),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _Entry extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Null for an entry that only shows something.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: onTap == null
          ? null
          : Icon(Icons.chevron_right, color: context.colors.textMuted),
      onTap: onTap,
    );
  }
}
