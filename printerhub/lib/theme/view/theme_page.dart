import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/theme/cubit/brightness_cubit.dart';
import 'package:printerhub/theme/widgets/theme_picker.dart';

/// Settings → Theme.
class ThemePage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.themeTitle)),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            Text(
              l10n.themeDescription,
              style: context.textTheme.bodyLarge?.copyWith(
                color: context.colors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const ThemePicker(),
            const SizedBox(height: AppSpacing.xxl),
            Text(l10n.themeBrightness, style: context.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(l10n.themeBrightnessSystem),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(l10n.themeBrightnessLight),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(l10n.themeBrightnessDark),
                ),
              ],
              selected: {context.watch<BrightnessCubit>().state},
              onSelectionChanged: (chosen) =>
                  context.read<BrightnessCubit>().select(chosen.single),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.themeBrightnessBody,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
