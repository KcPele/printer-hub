import 'dart:async';
import 'dart:io';

import 'package:app_ui/app_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/print/documents.dart';
import 'package:printerhub/print/print_words.dart';
import 'package:printerhub/printers/widgets/printer_choice_sheet.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/tools/cubit/make_cubit.dart';
import 'package:printerhub/tools/tool_words.dart';

/// The screen every tool that makes a document shares: what is asked
/// for, a button that makes it, and then the document to print or share.
class MakeScaffold extends StatelessWidget {
  const new({
    required this.title,
    required this.explanation,
    required this.state,
    required this.children,
    required this.onMake,
    required this.onShare,
    super.key,
  });

  final String title;
  final String explanation;
  final MakeState<Object?> state;

  /// The fields that say what to make.
  final List<Widget> children;

  /// Makes the document. Null when not enough has been said to make it.
  final VoidCallback? onMake;
  final VoidCallback onShare;

  Future<void> _print(BuildContext context, File file) async {
    final router = GoRouter.of(context);
    final printer = await choosePrinter(context);
    if (printer == null) return;
    unawaited(
      router.push(
        AppRoutes.printOn(printer.id),
        extra: PickedDocument.fromFile(file),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final file = state.file;
    final tone = context.semanticColors.status(AppStatus.success);

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
              if (file != null) ...[
                const SizedBox(height: AppSpacing.xl),
                Icon(
                  Icons.check_circle_outline,
                  size: 72,
                  color: tone.foreground,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.toolsMadeReady,
                  style: textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                if (printersThatPrint(context).isNotEmpty) ...[
                  AppSubmitButton(
                    label: l10n.scanPrint,
                    onPressed: () => _print(context, file),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                OutlinedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share),
                  label: Text(l10n.scanShare),
                ),
                const SizedBox(height: AppSpacing.xl),
              ] else ...[
                Text(
                  explanation,
                  style: textTheme.bodyLarge?.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              ...children,
              if (state.failure != null) ...[
                const SizedBox(height: AppSpacing.lg),
                AppNotice(message: ToolWords.failure(l10n, state.failure)),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppSubmitButton(
                label: file == null ? l10n.toolsMake : l10n.toolsMakeAgain,
                loading: state.working,
                onPressed: onMake,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The choice of paper every made document has.
class PaperField extends StatelessWidget {
  const new({
    required this.paper,
    required this.papers,
    required this.onChanged,
    super.key,
  });

  final ScanPaper paper;
  final List<ScanPaper> papers;

  /// Null while the choice cannot be changed.
  final ValueChanged<ScanPaper>? onChanged;

  @override
  Widget build(BuildContext context) {
    final changed = onChanged;
    return DropdownButtonFormField<String>(
      key: ValueKey(paper.name),
      initialValue: paper.name,
      isExpanded: true,
      decoration: InputDecoration(labelText: context.l10n.scanPaper),
      items: [
        for (final paper in papers)
          DropdownMenuItem(
            value: paper.name,
            child: Text(PrintWords.paper(paper.name)),
          ),
      ],
      onChanged: changed == null
          ? null
          : (name) => changed(papers.firstWhere((paper) => paper.name == name)),
    );
  }
}
