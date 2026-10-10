import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/print/documents.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/tools/cubit/pages_per_sheet_cubit.dart';
import 'package:printerhub/tools/made_pages.dart';
import 'package:printerhub/tools/view/make_scaffold.dart';

/// Sets the pages of a PDF two or four to a sheet, to save paper.
class PagesPerSheetPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final name = context.l10n.toolsPerSheetName(
      MaterialLocalizations.of(context).formatMediumDate(DateTime.now()),
    );
    return BlocProvider(
      create: (context) => PagesPerSheetCubit(
        sharer: context.read<ScanSharer>(),
        name: name,
        picker: context.read<PrintDocuments>().picker,
        renderer: context.read<PrintDocuments>().renderer,
      ),
      child: const PagesPerSheetView(),
    );
  }
}

class PagesPerSheetView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<PagesPerSheetCubit>();
    final state = context.watch<PagesPerSheetCubit>().state;
    final choices = state.choices;
    final document = choices.document;
    final enabled = !state.working;

    return MakeScaffold(
      title: l10n.toolsPerSheet,
      explanation: l10n.toolsPerSheetExplanation,
      state: state,
      onMake: cubit.ready(choices) ? cubit.make : null,
      onShare: cubit.share,
      children: [
        if (document != null) ...[
          AppCard(
            tone: AppCardTone.muted,
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf_outlined),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(document.name, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        OutlinedButton.icon(
          onPressed: enabled ? cubit.choose : null,
          icon: const Icon(Icons.folder_open_outlined),
          label: Text(
            document == null ? l10n.toolsChoosePdf : l10n.toolsChooseAnother,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SegmentedButton<int>(
          segments: [
            for (final count in pagesPerSheet)
              ButtonSegment(
                value: count,
                label: Text(l10n.toolsPerSheetCount(count)),
              ),
          ],
          selected: {choices.perSheet},
          onSelectionChanged: enabled
              ? (chosen) =>
                    cubit.change(choices.copyWith(perSheet: chosen.single))
              : null,
        ),
        const SizedBox(height: AppSpacing.lg),
        PaperField(
          paper: choices.paper,
          papers: sheetPapers,
          onChanged: enabled
              ? (paper) => cubit.change(choices.copyWith(paper: paper))
              : null,
        ),
      ],
    );
  }
}
