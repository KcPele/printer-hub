import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/documents/document_sources.dart';
import 'package:printerhub/documents/widgets/made_files.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/library/library.dart';
import 'package:printerhub/print/documents.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/session/session.dart';
import 'package:printerhub/tools/cubit/searchable_cubit.dart';
import 'package:printerhub/tools/view/tool_scaffold.dart';

/// Makes a scan or a picture into a PDF whose words can be searched and
/// copied.
class SearchablePage extends StatelessWidget {
  const new({this.document, super.key});

  /// A document that is already open, worked on at once. Null asks for
  /// one.
  final PickedDocument? document;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = SearchableCubit(
          picker: context.read<PrintDocuments>().picker,
          renderer: context.read<PrintDocuments>().renderer,
          reader: context.read<ScanTextReader>(),
          sharer: context.read<ScanSharer>(),
          keep: context.read<Library>().keeper(
            context.read<SessionCubit>().state.organization!.id,
          ),
        );
        final document = this.document;
        if (document != null) unawaited(cubit.start(document));
        return cubit;
      },
      child: const SearchableView(),
    );
  }
}

class SearchableView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SearchableCubit>();
    final state = context.watch<SearchableCubit>().state;
    final tone = context.semanticColors.status(AppStatus.success);

    return ToolScaffold(
      title: l10n.toolsSearchable,
      explanation: l10n.toolsSearchableExplanation,
      icon: Icons.manage_search_outlined,
      chooseLabel: l10n.toolsChooseFile,
      state: state,
      onChoose: cubit.choose,
      made: const {DocumentSources.searchablePdf},
      result: [
        const SizedBox(height: AppSpacing.xl),
        Icon(Icons.check_circle_outline, size: 72, color: tone.foreground),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.toolsSearchableReady,
          style: context.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.toolsSearchableReadyBody,
          style: context.textTheme.bodyLarge?.copyWith(
            color: context.colors.textMuted,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        MadeFiles(files: state.files, source: DocumentSources.searchablePdf),
        const SizedBox(height: AppSpacing.md),
        AppSubmitButton(label: l10n.scanShare, onPressed: cubit.share),
      ],
    );
  }
}
