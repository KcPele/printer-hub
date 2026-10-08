import 'package:app_ui/app_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/printers/printer_words.dart';
import 'package:printers_repository/printers_repository.dart';

/// Shows what a family of printers usually does and what to do on one
/// before adding it. [onAdd] starts adding a printer.
Future<void> showFamilySheet(
  BuildContext context,
  PrinterFamily family, {
  required VoidCallback onAdd,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => FamilySheet(
      family: family,
      onAdd: () {
        Navigator.of(sheetContext).pop();
        onAdd();
      },
    ),
  );
}

class FamilySheet extends StatelessWidget {
  const new({required this.family, required this.onAdd, super.key});

  final PrinterFamily family;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final summary = family.summary;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: AppIllustration(AppIllustrations.printer, height: 120),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            family.title,
            style: textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          if (summary != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              summary,
              style: textTheme.bodyLarge?.copyWith(
                color: context.colors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.catalogueUsually, style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            tone: AppCardTone.muted,
            child: Column(
              children: [
                for (final feature in PrinterWords.family(l10n, family))
                  _Line(
                    leading: Icon(
                      Icons.check_circle,
                      size: 20,
                      color: context.colors.emphasis,
                    ),
                    text: feature,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.catalogueUsuallyNote,
            style: textTheme.bodySmall?.copyWith(
              color: context.colors.textMuted,
            ),
          ),
          if (family.setupTips.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            Text(l10n.catalogueBefore, style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  for (final (index, tip) in family.setupTips.indexed)
                    _Line(
                      leading: Text(
                        '${index + 1}.',
                        style: textTheme.titleMedium?.copyWith(
                          color: context.colors.emphasis,
                        ),
                      ),
                      text: tip,
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppSubmitButton(label: l10n.catalogueAdd, onPressed: onAdd),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const new({required this.leading, required this.text});

  final Widget leading;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: AppSpacing.xxl, child: leading),
          Expanded(child: Text(text, style: context.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
