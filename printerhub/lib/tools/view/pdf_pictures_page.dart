import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/print/documents.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/tools/cubit/pdf_pictures_cubit.dart';
import 'package:printerhub/tools/view/tool_scaffold.dart';

/// Turns a PDF into pictures to share: one a page, or with [long] one
/// tall picture of every page.
class PdfPicturesPage extends StatelessWidget {
  const new({required this.long, super.key});

  final bool long;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PdfPicturesCubit(
        picker: context.read<PrintDocuments>().picker,
        renderer: context.read<PrintDocuments>().renderer,
        sharer: context.read<ScanSharer>(),
        long: long,
      ),
      child: const PdfPicturesView(),
    );
  }
}

class PdfPicturesView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<PdfPicturesCubit>();
    final state = context.watch<PdfPicturesCubit>().state;
    final tone = context.semanticColors.status(AppStatus.success);

    return ToolScaffold(
      title: cubit.long ? l10n.toolsLongPicture : l10n.toolsPictures,
      explanation: cubit.long
          ? l10n.toolsLongPictureExplanation
          : l10n.toolsPicturesExplanation,
      icon: cubit.long ? Icons.view_day_outlined : Icons.image_outlined,
      chooseLabel: l10n.toolsChoosePdf,
      state: state,
      onChoose: cubit.choose,
      result: [
        const SizedBox(height: AppSpacing.xl),
        Icon(Icons.check_circle_outline, size: 72, color: tone.foreground),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.toolsPicturesReady(state.files.length),
          style: context.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          tone: AppCardTone.muted,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final file in state.files)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                  child: Text(Uri.decodeComponent(file.uri.pathSegments.last)),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppSubmitButton(label: l10n.scanShare, onPressed: cubit.share),
      ],
    );
  }
}
