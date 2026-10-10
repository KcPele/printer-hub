import 'package:app_ui/app_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/tools/cubit/tool_state.dart';
import 'package:printerhub/tools/tool_words.dart';

/// The screen every tool shares: what it does, a button to choose a file,
/// a wait while it works, and then what came of it.
class ToolScaffold extends StatelessWidget {
  const new({
    required this.title,
    required this.explanation,
    required this.icon,
    required this.chooseLabel,
    required this.state,
    required this.onChoose,
    required this.result,
    super.key,
  });

  final String title;
  final String explanation;
  final IconData icon;
  final String chooseLabel;
  final ToolState state;
  final VoidCallback onChoose;

  /// What is shown once the tool is done, above "choose another".
  final List<Widget> result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = context.textTheme;
    final working = state.status == ToolStatus.working;
    final done = state.status == ToolStatus.done;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!done) ...[
                const SizedBox(height: AppSpacing.xl),
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Icon(icon, size: 40, color: colors.onPrimary),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  explanation,
                  style: textTheme.bodyLarge?.copyWith(color: colors.textMuted),
                  textAlign: TextAlign.center,
                ),
                if (state.failure != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppNotice(message: ToolWords.failure(l10n, state.failure)),
                ],
                const SizedBox(height: AppSpacing.xl),
                AppSubmitButton(
                  label: chooseLabel,
                  loading: working,
                  onPressed: onChoose,
                ),
              ] else ...[
                ...result,
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: onChoose,
                  child: Text(l10n.toolsChooseAnother),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
