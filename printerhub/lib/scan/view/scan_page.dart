import 'dart:async';
import 'dart:io';

import 'package:app_ui/app_ui.dart';
import 'package:documents_repository/documents_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/documents/widgets/recent_documents.dart';
import 'package:printerhub/errors/error_messages.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/library/library.dart';
import 'package:printerhub/print/documents.dart';
import 'package:printerhub/printers/cubit/printers_cubit.dart';
import 'package:printerhub/printers/widgets/printer_choice_sheet.dart';
import 'package:printerhub/scan/cubit/scan_cubit.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/scan/scan_words.dart';
import 'package:printerhub/scan/signature.dart';
import 'package:printerhub/scan/view/sign_page.dart';
import 'package:printerhub/scan/widgets/scan_options.dart';
import 'package:printerhub/session/session.dart';
import 'package:printerhub/workspace/cubit/features_cubit.dart';
import 'package:printers_repository/printers_repository.dart';

/// Scans: say how, scan, look the pages over, and keep the result. On one
/// printer's scanner, or, with no [printerId], with the phone's camera
/// alone, for someone who has no printer yet or is away from it.
class ScanPage extends StatelessWidget {
  const new({
    this.printerId,
    this.startWithPictures = false,
    this.startWithFiles = false,
    super.key,
  });

  final String? printerId;

  /// True opens the phone's file browser for pictures at once: the
  /// "Pictures to PDF" tool is this screen, begun that way.
  final bool startWithPictures;

  /// True opens it for PDFs and pictures at once: the "Merge files" and
  /// "Take pages from a PDF" tools are this screen, begun that way.
  final bool startWithFiles;

  @override
  Widget build(BuildContext context) {
    final id = printerId;
    final printer = context.select<PrintersCubit, PrinterRead?>(
      (cubit) => id == null ? null : cubit.state.printer(id),
    );
    if (id != null && printer == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.l10n.printerNotFound)),
      );
    }

    // Named for the day it is made on, until the person says otherwise.
    final name = context.l10n.scanName(
      MaterialLocalizations.of(context).formatMediumDate(DateTime.now()),
    );
    return BlocProvider(
      create: (context) => ScanCubit(
        printersRepository: context.read<PrintersRepository>(),
        jobsRepository: context.read<JobsRepository>(),
        documentsRepository: context.read<DocumentsRepository>(),
        library: context.read<Library>(),
        sharer: context.read<ScanSharer>(),
        textReader: context.read<ScanTextReader>(),
        camera: context.read<PageCamera>(),
        picker: context.read<PrintDocuments>().picker,
        renderer: context.read<PrintDocuments>().renderer,
        organizationId: context.read<SessionCubit>().state.organization!.id,
        printer: printer,
        name: name,
      )..startWith(pictures: startWithPictures, files: startWithFiles),
      child: ScanView(printer: printer),
    );
  }
}

class ScanView extends StatelessWidget {
  const new({required this.printer, super.key});

  /// The printer whose scanner is used, or null for the phone alone.
  final PrinterRead? printer;

  @override
  Widget build(BuildContext context) {
    final step = context.select<ScanCubit, ScanStep>(
      (cubit) => cubit.state.step,
    );
    final printer = this.printer;
    // A printer that has not said what it can do is taken to scan.
    final scans =
        printer != null && (printer.capabilities?.scan.supported ?? true);
    // The phone's camera, where the phone has one and the workspace has
    // it switched on.
    final camera =
        context.read<PageCamera>().available &&
        context.select<FeaturesCubit, bool>(
          (features) => features.enabled('camera_scan'),
        );

    return PopScope(
      // A scan in progress is stopped or finished, not walked away from.
      canPop: step != ScanStep.scanning && step != ScanStep.saving,
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.scanTitle)),
        body: SafeArea(
          child: switch (step) {
            ScanStep.choosing =>
              scans
                  ? _Choose(printer: printer, camera: camera)
                  : _CameraOnly(camera: camera, onPrinter: printer != null),
            ScanStep.scanning => const _Scanning(),
            ScanStep.review || ScanStep.saving => _Review(
              scans: scans,
              camera: camera,
              pictures: printer == null,
            ),
            ScanStep.saved => _Saved(
              printerId:
                  printer != null &&
                      (printer.capabilities?.print.supported ?? true)
                  ? printer.id
                  : null,
              // Made with the phone alone, it prints on any printer the
              // workspace has.
              anyPrinter: printer == null,
            ),
          },
        ),
      ),
    );
  }
}

const EdgeInsets _padding = EdgeInsets.fromLTRB(
  AppSpacing.page,
  AppSpacing.sm,
  AppSpacing.page,
  AppSpacing.xxl,
);

class _Choose extends StatelessWidget {
  const new({required this.printer, required this.camera});

  final PrinterRead printer;

  /// Whether the phone's camera is offered as another way.
  final bool camera;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ScanCubit>().state;

    return SingleChildScrollView(
      padding: _padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: AppIllustration(AppIllustrations.printer, height: 148),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.scanOptionsTitle, style: context.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          AppCard(child: ScanOptions(printer: printer)),
          if (state.card) ...[
            const SizedBox(height: AppSpacing.lg),
            AppNotice(status: AppStatus.info, message: l10n.scanCardPlace),
          ],
          if (state.failure != null) ...[
            const SizedBox(height: AppSpacing.lg),
            AppNotice(message: ScanWords.failure(l10n, state.failure)),
          ],
          if (state.error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            AppNotice(message: errorMessage(l10n, state.error)),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppSubmitButton(
            label: state.card ? l10n.scanCardFrontAction : l10n.scanAction,
            onPressed: context.read<ScanCubit>().scan,
          ),
          // A card is scanned on the glass, where its size is known.
          if (camera && !state.card) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: context.read<ScanCubit>().useCamera,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(l10n.scanCamera),
            ),
          ],
          // What was scanned before is here to be found again.
          const SizedBox(height: AppSpacing.xl),
          RecentDocuments(title: l10n.documentsRecent),
        ],
      ),
    );
  }
}

/// The scan screen of a printer with no scanner: the phone's camera does
/// the scanning, where there is one.
class _CameraOnly extends StatelessWidget {
  const new({required this.camera, required this.onPrinter});

  final bool camera;

  /// True when this is the scan screen of a printer, which then has no
  /// scanner. False when the scan is made with the phone alone.
  final bool onPrinter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final failure = context.select<ScanCubit, String?>(
      (cubit) => cubit.state.failure,
    );
    final card = context.select<ScanCubit, bool>((cubit) => cubit.state.card);
    final reading = context.select<ScanCubit, bool>(
      (cubit) => cubit.state.reading,
    );

    return SingleChildScrollView(
      padding: _padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: AppIllustration(AppIllustrations.printer, height: 148),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            onPrinter ? l10n.scanNoScanner : l10n.scanPhoneTitle,
            style: context.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          if (camera) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              onPrinter ? l10n.scanCameraInstead : l10n.scanPhoneBody,
              style: context.textTheme.bodyLarge?.copyWith(
                color: context.colors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            // With no glass, the camera takes the two sides of a card.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.scanCard),
              subtitle: Text(l10n.scanCardBody),
              value: card,
              onChanged: (on) => context.read<ScanCubit>().asCard(card: on),
            ),
            if (failure != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppNotice(message: ScanWords.failure(l10n, failure)),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppSubmitButton(
              label: card ? l10n.scanCardFrontAction : l10n.scanCamera,
              onPressed: context.read<ScanCubit>().useCamera,
            ),
          ],
          // With the phone alone, photos already taken can be the pages.
          if (!onPrinter && !card) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: reading ? null : context.read<ScanCubit>().addPictures,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(l10n.scanChoosePictures),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: reading ? null : context.read<ScanCubit>().addFiles,
              icon: const Icon(Icons.folder_open_outlined),
              label: Text(l10n.scanChooseFiles),
            ),
            if (reading) ...[
              const SizedBox(height: AppSpacing.lg),
              const LinearProgressIndicator(),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.scanReadingFiles, textAlign: TextAlign.center),
            ],
          ],
          // What was scanned before is here to be found again.
          const SizedBox(height: AppSpacing.xl),
          RecentDocuments(title: l10n.documentsRecent),
        ],
      ),
    );
  }
}

class _Scanning extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final progress = context.select<ScanCubit, ScanProgress?>(
      (cubit) => cubit.state.progress,
    );

    return SingleChildScrollView(
      padding: _padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          const Center(
            child: AppIllustration(AppIllustrations.printer, height: 180),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: AppSpacing.lg),
          Text(
            ScanWords.stage(l10n, progress),
            style: context.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          OutlinedButton(
            onPressed: context.read<ScanCubit>().cancel,
            child: Text(l10n.scanCancel),
          ),
        ],
      ),
    );
  }
}

class _Review extends StatelessWidget {
  const new({
    required this.scans,
    required this.camera,
    required this.pictures,
  });

  /// Whether the printer can scan more pages.
  final bool scans;

  /// Whether pictures from the phone can be added: with the phone alone.
  final bool pictures;

  /// Whether the phone's camera can add pages.
  final bool camera;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final cubit = context.read<ScanCubit>();
    final state = context.watch<ScanCubit>().state;
    // Nothing is changed while the pages are put together, or while more
    // are being read in.
    final saving = state.step == ScanStep.saving || state.reading;
    final failure = state.failure;

    return SingleChildScrollView(
      padding: _padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            initialValue: state.name,
            enabled: !saving,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.scanNameLabel),
            onChanged: cubit.rename,
          ),
          if (failure != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppNotice(
              status: failure == 'scan.storage'
                  ? AppStatus.error
                  : AppStatus.warning,
              message: failure == 'scan.storage'
                  ? ScanWords.failure(l10n, failure)
                  : '${ScanWords.failure(l10n, failure)} '
                        '${l10n.scanKeptPages}',
            ),
          ],
          if (state.error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppNotice(message: errorMessage(l10n, state.error)),
          ],
          if (state.awaitsBack) ...[
            const SizedBox(height: AppSpacing.sm),
            AppNotice(
              status: AppStatus.info,
              message: scans ? l10n.scanCardTurn : l10n.scanCardTurnCamera,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.scanPagesTitle, style: textTheme.titleLarge),
          if (state.pages.length > 1) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.scanPagesHint,
              style: textTheme.bodySmall?.copyWith(
                color: context.colors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorderItem: cubit.move,
            children: [
              for (final (index, page) in state.pages.indexed)
                Padding(
                  key: ValueKey(page.file.path),
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: context.shapes.chipRadius,
                          child: SizedBox(
                            width: 56,
                            height: 72,
                            child: ColoredBox(
                              color: context.colors.surfaceMuted,
                              child: page.mimeType == 'application/pdf'
                                  ? const Icon(Icons.picture_as_pdf_outlined)
                                  : Image.file(
                                      page.file,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          const Icon(Icons.image_outlined),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ScanWords.page(l10n, index, card: state.card),
                                style: textTheme.titleMedium,
                              ),
                              // Never passed off as the printer's scan.
                              if (state.fromCamera(page))
                                Text(
                                  l10n.scanFromCamera,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: context.colors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (page.mimeType != 'application/pdf')
                          IconButton(
                            tooltip: l10n.scanRotatePage,
                            onPressed: saving ? null : () => cubit.rotate(page),
                            icon: const Icon(Icons.rotate_right),
                          ),
                        IconButton(
                          tooltip: l10n.scanRemovePage,
                          onPressed: saving ? null : () => cubit.remove(page),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (scans)
            OutlinedButton.icon(
              onPressed: saving ? null : cubit.scan,
              icon: const Icon(Icons.add),
              label: Text(
                state.awaitsBack
                    ? l10n.scanCardBackAction
                    : state.card
                    ? l10n.scanCardAnother
                    : l10n.scanMore,
              ),
            ),
          // A card's sides come from the camera only where there is no
          // glass to scan them on.
          if (camera && (!state.card || !scans)) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: saving ? null : cubit.useCamera,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(
                state.awaitsBack
                    ? l10n.scanCardBackAction
                    : state.card
                    ? l10n.scanCardAnother
                    : l10n.scanCameraMore,
              ),
            ),
          ],
          if (pictures && !state.card) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: saving ? null : cubit.addPictures,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(l10n.scanAddPictures),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: saving ? null : cubit.addFiles,
              icon: const Icon(Icons.folder_open_outlined),
              label: Text(l10n.scanAddFiles),
            ),
          ],
          if (state.reading) ...[
            const SizedBox(height: AppSpacing.md),
            const LinearProgressIndicator(),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.scanReadingFiles, textAlign: TextAlign.center),
          ],
          if (state.redrawn) ...[
            const SizedBox(height: AppSpacing.md),
            AppNotice(status: AppStatus.info, message: l10n.scanRedrawn),
          ],
          const SizedBox(height: AppSpacing.lg),
          _Finishing(enabled: !saving),
          const SizedBox(height: AppSpacing.lg),
          AppSubmitButton(
            label: l10n.scanSave,
            loading: saving,
            onPressed: () => cubit.save(
              readText: context.read<FeaturesCubit>().enabled('local_ocr'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: saving ? null : cubit.startOver,
            child: Text(l10n.scanStartOver),
          ),
        ],
      ),
    );
  }
}

/// What is done to the pages as they are saved: a look, a date in the
/// corner, a word across the page. The pages themselves are not changed,
/// so going back and saving again undoes any of it.
class _Finishing extends StatelessWidget {
  const new({required this.enabled});

  final bool enabled;

  /// Opens the signing screen over this one, and sets the signature
  /// where it was put.
  Future<void> _sign(BuildContext context) async {
    final cubit = context.read<ScanCubit>();
    final state = cubit.state;
    final store = context.read<SignatureStore>();
    final placed = await Navigator.of(context).push<PlacedSignature>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RepositoryProvider.value(
          value: store,
          child: SignPage(
            pages: [for (final page in state.pages) page.file],
            paper: ScanPaper.named(state.choices.mediaSize),
            placed: state.finish.signature,
          ),
        ),
      ),
    );
    if (placed != null) {
      cubit.finishWith(cubit.state.finish.copyWith(signature: () => placed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ScanCubit>();
    final state = context.watch<ScanCubit>().state;
    final finish = state.finish;
    // A page the scanner made as a PDF cannot be redrawn; a stamp and a
    // watermark are set on the pages of the PDF the app makes.
    final pictures = state.pages.every(
      (page) => page.mimeType != 'application/pdf',
    );
    final asPdf =
        pictures && (state.card || state.choices.format == 'application/pdf');
    if (!pictures) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.scanFinishTitle, style: context.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<ScanLook>(
            key: ValueKey(finish.look),
            initialValue: finish.look,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.scanLook),
            items: [
              for (final look in ScanLook.values)
                DropdownMenuItem(
                  value: look,
                  child: Text(ScanWords.look(l10n, look)),
                ),
            ],
            onChanged: enabled
                ? (look) => cubit.finishWith(finish.copyWith(look: look))
                : null,
          ),
          if (asPdf) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.scanStamp),
              subtitle: Text(l10n.scanStampBody),
              value: finish.stamp != null,
              onChanged: enabled
                  ? (on) {
                      final now = DateTime.now();
                      final words = MaterialLocalizations.of(context);
                      final date = words.formatMediumDate(now);
                      final time = words.formatTimeOfDay(
                        TimeOfDay.fromDateTime(now),
                      );
                      cubit.finishWith(
                        finish.copyWith(
                          stamp: () => on ? '$date, $time' : null,
                        ),
                      );
                    }
                  : null,
            ),
            // A card's sheet is two small pictures: there is no page to
            // sign on.
            if (!state.card) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: enabled ? () => _sign(context) : null,
                icon: const Icon(Icons.draw_outlined),
                label: Text(
                  finish.signature == null
                      ? l10n.scanSignAdd
                      : l10n.scanSignChange,
                ),
              ),
              if (finish.signature != null)
                TextButton(
                  onPressed: enabled
                      ? () => cubit.finishWith(
                          finish.copyWith(signature: () => null),
                        )
                      : null,
                  child: Text(l10n.scanSignRemove),
                ),
              const SizedBox(height: AppSpacing.md),
            ],
            TextFormField(
              initialValue: finish.watermark,
              enabled: enabled,
              maxLength: 24,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: l10n.scanWatermark,
                helperText: l10n.scanWatermarkHint,
              ),
              onChanged: (words) =>
                  cubit.finishWith(finish.copyWith(watermark: words)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Saved extends StatelessWidget {
  const new({required this.printerId, this.anyPrinter = false});

  /// The printer the scan can be printed on: the one it was made on, when
  /// that prints.
  final String? printerId;

  /// True when the scan belongs to no printer, and is printed on one the
  /// person picks from the workspace's.
  final bool anyPrinter;

  /// Opens printing of [file] on [printerId], or on a printer the person
  /// picks.
  Future<void> _print(BuildContext context, File file) async {
    final router = GoRouter.of(context);
    final id = printerId ?? (await choosePrinter(context))?.id;
    if (id == null) return;
    unawaited(
      router.push(AppRoutes.printOn(id), extra: PickedDocument.fromFile(file)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final cubit = context.read<ScanCubit>();
    final state = context.watch<ScanCubit>().state;
    final files = [for (final file in state.files) file.uri.pathSegments.last];
    final keeping = state.kept == ScanKept.keeping;
    final tone = context.semanticColors.status(AppStatus.success);

    return SingleChildScrollView(
      padding: _padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Icon(Icons.check_circle_outline, size: 72, color: tone.foreground),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.scanSavedTitle,
            style: textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.scanSavedBody,
            style: textTheme.bodyLarge?.copyWith(
              color: context.colors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            tone: AppCardTone.muted,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final file in files)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xxs,
                    ),
                    child: Text(Uri.decodeComponent(file)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (state.error != null) ...[
            AppNotice(message: errorMessage(l10n, state.error)),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppSubmitButton(label: l10n.scanShare, onPressed: cubit.share),
          const SizedBox(height: AppSpacing.sm),
          // One file is one print. Several pictures are shared instead.
          if (state.files.length == 1 &&
              (printerId != null ||
                  (anyPrinter && printersThatPrint(context).isNotEmpty))) ...[
            OutlinedButton.icon(
              onPressed: keeping
                  ? null
                  : () => _print(context, state.files.single),
              icon: const Icon(Icons.print_outlined),
              label: Text(l10n.scanPrint),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          // It is kept without being asked: here is where.
          if (keeping)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(l10n.scanKeeping, style: textTheme.bodySmall),
              ],
            )
          else if (state.kept != ScanKept.no) ...[
            Center(
              child: StatusPill(
                status: state.kept == ScanKept.yes
                    ? AppStatus.success
                    : AppStatus.neutral,
                label: state.kept == ScanKept.yes
                    ? l10n.scanKeptInAccount
                    : l10n.scanKeptOnPhone,
                icon: state.kept == ScanKept.yes
                    ? Icons.cloud_done_outlined
                    : Icons.phone_iphone_outlined,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              state.kept == ScanKept.yes
                  ? l10n.scanKeptInAccountBody
                  : l10n.scanKeptOnPhoneBody,
              style: textTheme.bodySmall?.copyWith(
                color: context.colors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            if (state.textRead != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                state.textRead! ? l10n.scanTextKept : l10n.scanTextNotRead,
                style: textTheme.bodySmall?.copyWith(
                  color: context.colors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            // Its owner's alone until they say otherwise.
            if (state.kept == ScanKept.yes) ...[
              const SizedBox(height: AppSpacing.sm),
              if (state.shared)
                Center(
                  child: StatusPill(
                    status: AppStatus.info,
                    label: l10n.documentShared,
                    icon: Icons.groups_outlined,
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: state.sharing ? null : cubit.shareWithWorkspace,
                  icon: state.sharing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.groups_outlined),
                  label: Text(l10n.documentShare),
                ),
            ],
          ],
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: keeping || state.sharing ? null : cubit.edit,
            child: Text(l10n.scanEdit),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => context.pop(),
            child: Text(l10n.scanDone),
          ),
        ],
      ),
    );
  }
}
