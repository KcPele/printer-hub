import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/theme/cubit/theme_cubit.dart';

/// The three themes side by side. Tapping one applies it.
class ThemePicker extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selected = context.select<ThemeCubit, AppThemeId>(
      (cubit) => cubit.state,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final theme in AppTheme.all) ...[
          if (theme != AppTheme.all.first) const SizedBox(width: AppSpacing.md),
          Expanded(
            child: AppThemePreview(
              theme: theme,
              label: switch (theme.id) {
                AppThemeId.volt => l10n.themeVolt,
                AppThemeId.indigo => l10n.themeIndigo,
                AppThemeId.mint => l10n.themeMint,
              },
              selected: theme.id == selected,
              onTap: () => context.read<ThemeCubit>().select(theme.id),
            ),
          ),
        ],
      ],
    );
  }
}
