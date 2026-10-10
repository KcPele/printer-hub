import 'package:app_ui/app_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/print/documents.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/tools/cubit/extract_text_cubit.dart';
import 'package:printerhub/tools/view/tool_scaffold.dart';

/// Reads the words in a PDF or a picture, to copy or share.
class ExtractTextPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ExtractTextCubit(
        picker: context.read<PrintDocuments>().picker,
        renderer: context.read<PrintDocuments>().renderer,
        reader: context.read<ScanTextReader>(),
        sharer: context.read<ScanSharer>(),
      ),
      child: const ExtractTextView(),
    );
  }
}

class ExtractTextView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ExtractTextCubit>();
    final state = context.watch<ExtractTextCubit>().state;

    return ToolScaffold(
      title: l10n.toolsText,
      explanation: l10n.toolsTextExplanation,
      icon: Icons.text_snippet_outlined,
      chooseLabel: l10n.toolsChooseFile,
      state: state,
      onChoose: cubit.choose,
      result: [
        Text(state.name, style: context.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          tone: AppCardTone.muted,
          child: SelectableText(
            state.text,
            style: context.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSubmitButton(
          label: l10n.toolsCopy,
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await Clipboard.setData(ClipboardData(text: state.text));
            messenger.showSnackBar(SnackBar(content: Text(l10n.toolsCopied)));
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: cubit.share,
          icon: const Icon(Icons.ios_share),
          label: Text(l10n.toolsShareText),
        ),
      ],
    );
  }
}
