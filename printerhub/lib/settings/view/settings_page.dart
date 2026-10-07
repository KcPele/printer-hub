import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/theme/theme.dart';

class SettingsPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.select<ThemeCubit, AppThemeId>(
      (cubit) => cubit.state,
    );

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
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(Icons.chevron_right, color: context.colors.textMuted),
      onTap: onTap,
    );
  }
}
