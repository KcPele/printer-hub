import 'package:app_ui/app_ui.dart';
import 'package:documents_repository/documents_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/errors/error_messages.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/print/documents.dart';
import 'package:printerhub/printers/cubit/printers_cubit.dart';
import 'package:printerhub/scan/cubit/scan_cubit.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/scan/scan_words.dart';
import 'package:printerhub/scan/widgets/scan_options.dart';
import 'package:printerhub/session/session.dart';
import 'package:printerhub/workspace/cubit/features_cubit.dart';
import 'package:printers_repository/printers_repository.dart';

/// Scans on one printer: say how, scan, look the pages over, and keep the
/// result.
class ScanPage extends StatelessWidget {
  const new({required this.printerId, super.key});

  final String printerId;

  @override
  Widget build(BuildContext context) {
    final printer = context.select<PrintersCubit, PrinterRead?>(
      (cubit) => cubit.state.printer(printerId),
    );
    if (printer == null) {
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
        sharer: context.read<ScanSharer>(),
        textReader: context.read<ScanTextReader>(),
        camera: context.read<PageCamera>(),
        organizationId: context.read<SessionCubit>().state.organization!.id,
        printer: printer,
        name: name,
      ),
      child: ScanView(printer: printer),
    );
  }
}

class ScanView extends StatelessWidget {
  const new({required this.printer, super.key});

  final PrinterRead printer;

  @override
  Widget build(BuildContext context) {
    final step = context.select<ScanCubit, ScanStep>(
      (cubit) => cubit.state.step,
    );
    // A printer that has not said what it can do is taken to scan.
    final scans = printer.capabilities?.scan.supported ?? true;
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
                  : _CameraOnly(camera: camera),
            ScanStep.scanning => const _Scanning(),
            ScanStep.review ||
            ScanStep.saving => _Review(scans: scans, camera: camera),
            ScanStep.saved => _Saved(
              printerId: (printer.capabilities?.print.supported ?? true)
                  ? printer.id
                  : null,
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
        ],
      ),
    );
  }
}

/// The scan screen of a printer with no scanner: the phone's camera does
/// the scanning, where there is one.
class _CameraOnly extends StatelessWidget {
  const new({required this.camera});

  final bool camera;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final failure = context.select<ScanCubit, String?>(
      (cubit) => cubit.state.failure,
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
            l10n.scanNoScanner,
            style: context.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          if (camera) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.scanCameraInstead,
              style: context.textTheme.bodyLarge?.copyWith(
                color: context.colors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            if (failure != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppNotice(message: ScanWords.failure(l10n, failure)),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppSubmitButton(
              label: l10n.scanCamera,
              onPressed: context.read<ScanCubit>().useCamera,
            ),
          ],
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
  const new({required this.scans, required this.camera});

  /// Whether the printer can scan more pages.
  final bool scans;

  /// Whether the phone's camera can add pages.
  final bool camera;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final cubit = context.read<ScanCubit>();
    final state = context.watch<ScanCubit>().state;
    final saving = state.step == ScanStep.saving;
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
            AppNotice(status: AppStatus.info, message: l10n.scanCardTurn),
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
          if (camera && !state.card) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: saving ? null : cubit.useCamera,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(l10n.scanCameraMore),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          AppSubmitButton(
            label: l10n.scanSave,
            loading: saving,
            onPressed: cubit.save,
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

class _Saved extends StatelessWidget {
  const new({required this.printerId});

  /// The printer the scan can be printed on: the one it was made on, when
  /// that prints.
  final String? printerId;

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
          if (state.failure != null) ...[
            AppNotice(message: ScanWords.failure(l10n, state.failure)),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (state.error != null) ...[
            AppNotice(message: errorMessage(l10n, state.error)),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppSubmitButton(label: l10n.scanShare, onPressed: cubit.share),
          const SizedBox(height: AppSpacing.sm),
          // One file is one print. Several pictures are shared instead.
          if (state.files.length == 1 && printerId != null) ...[
            OutlinedButton.icon(
              onPressed: keeping
                  ? null
                  : () => context.push(
                      AppRoutes.printOn(printerId!),
                      extra: PickedDocument.fromFile(state.files.single),
                    ),
              icon: const Icon(Icons.print_outlined),
              label: Text(l10n.scanPrint),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (state.kept == ScanKept.yes) ...[
            Center(
              child: StatusPill(
                status: AppStatus.success,
                label: l10n.scanKeptInWorkspace,
                icon: Icons.cloud_done_outlined,
              ),
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
          ] else
            OutlinedButton.icon(
              onPressed: keeping
                  ? null
                  : () => cubit.keep(
                      readText: context.read<FeaturesCubit>().enabled(
                        'local_ocr',
                      ),
                    ),
              icon: keeping
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(l10n.scanKeep),
            ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: keeping ? null : cubit.edit,
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
