import 'dart:async';
import 'dart:io';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/print/documents.dart';
import 'package:printerhub/print/print_words.dart';
import 'package:printerhub/printers/widgets/printer_choice_sheet.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/tools/cubit/photo_sheet_cubit.dart';
import 'package:printerhub/tools/photo_sheet.dart';
import 'package:printerhub/tools/tool_words.dart';

/// Lays photos out on a sheet to print: one, two, or four to a page, or a
/// sheet of passport photos.
class PhotoSheetPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    // Named for the day it is made on, as a scan is.
    final name = context.l10n.toolsPhotosName(
      MaterialLocalizations.of(context).formatMediumDate(DateTime.now()),
    );
    return BlocProvider(
      create: (context) => PhotoSheetCubit(
        picker: context.read<PrintDocuments>().picker,
        sharer: context.read<ScanSharer>(),
        name: name,
      ),
      child: const PhotoSheetView(),
    );
  }
}

class PhotoSheetView extends StatelessWidget {
  const new({super.key});

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
    final cubit = context.read<PhotoSheetCubit>();
    final state = context.watch<PhotoSheetCubit>().state;
    final file = state.file;
    final tone = context.semanticColors.status(AppStatus.success);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.toolsPhotos)),
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
                  l10n.toolsPhotosReady,
                  style: textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.toolsPhotosReadyBody,
                  style: textTheme.bodyLarge?.copyWith(
                    color: context.colors.textMuted,
                  ),
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
                  onPressed: cubit.share,
                  icon: const Icon(Icons.ios_share),
                  label: Text(l10n.scanShare),
                ),
                const SizedBox(height: AppSpacing.xl),
              ] else ...[
                Text(
                  l10n.toolsPhotosExplanation,
                  style: textTheme.bodyLarge?.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              for (final photo in state.photos)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: context.shapes.chipRadius,
                          child: SizedBox.square(
                            dimension: 56,
                            child: ColoredBox(
                              color: context.colors.surfaceMuted,
                              child: Image.file(
                                File(photo.path),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.image_outlined),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Text(
                            photo.name,
                            style: textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.toolsPhotosRemove,
                          onPressed: state.working
                              ? null
                              : () => cubit.remove(photo),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: state.working ? null : cubit.choose,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  state.photos.isEmpty
                      ? l10n.toolsPhotosChoose
                      : l10n.toolsPhotosAdd,
                ),
              ),
              if (state.photos.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<PhotoLayout>(
                        key: ValueKey(state.layout),
                        initialValue: state.layout,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l10n.toolsPhotosLayout,
                        ),
                        items: [
                          for (final layout in PhotoLayout.values)
                            DropdownMenuItem(
                              value: layout,
                              child: Text(ToolWords.layout(l10n, layout)),
                            ),
                        ],
                        onChanged: state.working
                            ? null
                            : (layout) => cubit.setLayout(layout!),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      DropdownButtonFormField<String>(
                        key: ValueKey(state.paper.name),
                        initialValue: state.paper.name,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: l10n.scanPaper),
                        items: [
                          for (final paper in photoPapers)
                            DropdownMenuItem(
                              value: paper.name,
                              child: Text(PrintWords.paper(paper.name)),
                            ),
                        ],
                        onChanged: state.working
                            ? null
                            : (name) => cubit.setPaper(
                                photoPapers.firstWhere(
                                  (paper) => paper.name == name,
                                ),
                              ),
                      ),
                      if (state.layout == PhotoLayout.passport) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l10n.toolsPhotosPassportBody(
                            passportPhotosOn(state.paper),
                          ),
                          style: textTheme.bodySmall?.copyWith(
                            color: context.colors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (state.failure != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppNotice(message: ToolWords.failure(l10n, state.failure)),
                ],
                const SizedBox(height: AppSpacing.lg),
                AppSubmitButton(
                  label: file == null
                      ? l10n.toolsPhotosMake
                      : l10n.toolsPhotosMakeAgain,
                  loading: state.working,
                  onPressed: cubit.make,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
