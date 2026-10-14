import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/documents/document_sources.dart';
import 'package:printerhub/documents/widgets/made_files.dart';
import 'package:printerhub/documents/widgets/recent_documents.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/library/library.dart';
import 'package:printerhub/pictures/picture_edits.dart';
import 'package:printerhub/print/documents.dart';
import 'package:printerhub/print/print_words.dart';
import 'package:printerhub/printers/widgets/printer_choice_sheet.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/session/session.dart';
import 'package:printerhub/tools/cubit/id_photo_cubit.dart';
import 'package:printerhub/tools/id_photo.dart';
import 'package:printerhub/tools/photo_sheet.dart';
import 'package:printerhub/tools/tool_words.dart';

/// Passport and visa photos: a photo framed to an official size, as many
/// to a sheet as it holds, at the exact size.
class IdPhotoPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final name = context.l10n.toolsIdPhotoName(
      MaterialLocalizations.of(context).formatMediumDate(DateTime.now()),
    );
    return BlocProvider(
      create: (context) => IdPhotoCubit(
        picker: context.read<PrintDocuments>().picker,
        sharer: context.read<ScanSharer>(),
        keep: context.read<Library>().keeper(
          context.read<SessionCubit>().state.organization!.id,
        ),
        name: name,
      ),
      child: const IdPhotoView(),
    );
  }
}

/// What a size is called: its measure, and who asks for it.
String idPhotoSizeName(AppLocalizations l10n, IdPhotoSize size) {
  return switch (size.key) {
    '51x51' => l10n.toolsIdPhotoSize5151,
    '33x48' => l10n.toolsIdPhotoSize3348,
    '50x70' => l10n.toolsIdPhotoSize5070,
    _ => l10n.toolsIdPhotoSize3545,
  };
}

class IdPhotoView extends StatelessWidget {
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
    final cubit = context.read<IdPhotoCubit>();
    final state = context.watch<IdPhotoCubit>().state;
    final photo = state.photo;
    final file = state.file;
    final tone = context.semanticColors.status(AppStatus.success);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.toolsIdPhoto)),
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
                  l10n.toolsIdPhotoReady,
                  style: textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.toolsIdPhotoCopies(state.copies),
                  style: textTheme.bodyLarge?.copyWith(
                    color: context.colors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                MadeFiles(files: [file], source: DocumentSources.idPhoto),
                const SizedBox(height: AppSpacing.md),
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
                  l10n.toolsIdPhotoExplanation,
                  style: textTheme.bodyLarge?.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              DropdownButtonFormField<String>(
                key: ValueKey(state.size.key),
                initialValue: state.size.key,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.toolsIdPhotoSize),
                items: [
                  for (final size in idPhotoSizes)
                    DropdownMenuItem(
                      value: size.key,
                      child: Text(
                        idPhotoSizeName(l10n, size),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: state.working
                    ? null
                    : (key) => cubit.setSize(
                        idPhotoSizes.firstWhere((size) => size.key == key),
                      ),
              ),
              if (photo != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.toolsIdPhotoFrame,
                  style: textTheme.bodyMedium?.copyWith(
                    color: context.colors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: _Framing(
                    // A new photo, or a new size, is framed afresh.
                    key: ValueKey('${photo.path} ${state.size.key}'),
                    photo: photo,
                    width: state.width,
                    height: state.height,
                    aspect: state.size.aspect,
                    onFramed: cubit.frameTo,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: state.working ? null : cubit.choose,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  photo == null
                      ? l10n.toolsIdPhotoChoose
                      : l10n.toolsIdPhotoAnother,
                ),
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
                        photoPapers.firstWhere((paper) => paper.name == name),
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppNotice(
                status: AppStatus.info,
                message: l10n.toolsIdPhotoCheck,
              ),
              if (state.failure != null) ...[
                const SizedBox(height: AppSpacing.lg),
                AppNotice(message: ToolWords.failure(l10n, state.failure)),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppSubmitButton(
                label: file == null
                    ? l10n.toolsIdPhotoMake
                    : l10n.toolsPhotosMakeAgain,
                loading: state.working,
                onPressed: photo == null ? null : cubit.make,
              ),
              const SizedBox(height: AppSpacing.xxl),
              RecentDocuments(
                title: l10n.documentsRecentHere,
                sources: const {DocumentSources.idPhoto},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The photo in a frame of the size asked for, moved and pinched until
/// the face fills the outline. Says what part of the photo is in the
/// frame each time it is let go.
class _Framing extends StatefulWidget {
  const new({
    required this.photo,
    required this.width,
    required this.height,
    required this.aspect,
    required this.onFramed,
    super.key,
  });

  final File photo;
  final int width;
  final int height;

  /// The frame's width over its height.
  final double aspect;
  final ValueChanged<CropBox> onFramed;

  @override
  State<_Framing> createState() => _FramingState();
}

class _FramingState extends State<_Framing> {
  final TransformationController _moved = TransformationController();

  /// The frame, and the photo laid out to cover it, in screen points.
  late Size _frame;
  late Size _laid;

  @override
  void dispose() {
    _moved.dispose();
    super.dispose();
  }

  /// The part of the photo that is in the frame, in parts of the photo.
  CropBox _framed() {
    final moved = _moved.value;
    final scale = moved.getMaxScaleOnAxis();
    final shift = moved.getTranslation();
    final left = (-shift.x / scale) / _laid.width;
    final top = (-shift.y / scale) / _laid.height;
    return CropBox(
      left: left.clamp(0, 1),
      top: top.clamp(0, 1),
      right: (left + _frame.width / scale / _laid.width).clamp(0, 1),
      bottom: (top + _frame.height / scale / _laid.height).clamp(0, 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = min(constraints.maxWidth, 260).toDouble();
        _frame = Size(width, width / widget.aspect);
        final picture = widget.width / widget.height;
        // The photo covers the frame, as much of it as fits.
        _laid = picture > widget.aspect
            ? Size(_frame.height * picture, _frame.height)
            : Size(_frame.width, _frame.width / picture);
        // It begins in the middle.
        if (_moved.value.isIdentity()) {
          _moved.value = Matrix4.translationValues(
            -(_laid.width - _frame.width) / 2,
            -(_laid.height - _frame.height) / 2,
            0,
          );
        }

        return ClipRRect(
          borderRadius: context.shapes.chipRadius,
          child: SizedBox.fromSize(
            size: _frame,
            child: Stack(
              children: [
                InteractiveViewer(
                  key: const ValueKey('id-photo-frame'),
                  transformationController: _moved,
                  constrained: false,
                  maxScale: 5,
                  onInteractionEnd: (_) => widget.onFramed(_framed()),
                  child: SizedBox.fromSize(
                    size: _laid,
                    // It was read when it was chosen.
                    child: Image.file(widget.photo, fit: BoxFit.fill),
                  ),
                ),
                // Where the head goes, as official photos ask: centred,
                // filling most of the height. White, to be seen on any
                // photo.
                const Positioned.fill(
                  child: IgnorePointer(
                    child: Align(
                      alignment: Alignment(0, -0.2),
                      child: FractionallySizedBox(
                        widthFactor: 0.56,
                        heightFactor: 0.62,
                        child: DecoratedBox(
                          decoration: ShapeDecoration(
                            shape: OvalBorder(
                              side: BorderSide(color: Colors.white70, width: 2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
