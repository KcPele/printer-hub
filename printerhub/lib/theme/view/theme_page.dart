import 'package:app_ui/app_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';
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
          ],
        ),
      ),
    );
  }
}
