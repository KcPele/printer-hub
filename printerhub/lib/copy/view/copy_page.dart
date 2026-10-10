import 'package:app_ui/app_ui.dart';
import 'package:documents_repository/documents_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/copy/copy_words.dart';
import 'package:printerhub/copy/cubit/copy_cubit.dart';
import 'package:printerhub/errors/error_messages.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/library/library.dart';
import 'package:printerhub/print/documents.dart';
import 'package:printerhub/printers/cubit/printers_cubit.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/session/session.dart';
import 'package:printers_repository/printers_repository.dart';

/// Copies on one printer: put the page on the glass or in the feeder,
/// say how many, and the printer's scanner and the printer do the rest.
class CopyPage extends StatelessWidget {
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

    // Named for the day it is made on, as a scan is.
    final name = context.l10n.copyName(
      MaterialLocalizations.of(context).formatMediumDate(DateTime.now()),
    );
    return BlocProvider(
      create: (context) => CopyCubit(
        printersRepository: context.read<PrintersRepository>(),
        jobsRepository: context.read<JobsRepository>(),
        documentsRepository: context.read<DocumentsRepository>(),
        library: context.read<Library>(),
        documents: context.read<PrintDocuments>(),
        sharer: context.read<ScanSharer>(),
        textReader: context.read<ScanTextReader>(),
        camera: context.read<PageCamera>(),
        organizationId: context.read<SessionCubit>().state.organization!.id,
        printer: printer,
        name: name,
      ),
      child: CopyView(printer: printer),
    );
  }
}

class CopyView extends StatelessWidget {
  const new({required this.printer, super.key});

  final PrinterRead printer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final cubit = context.read<CopyCubit>();
    final state = context.watch<CopyCubit>().state;
    final working =
        state.step == CopyStep.scanning || state.step == CopyStep.printing;
    final offers = printer.capabilities;
    final feeder = (offers?.scan.sources ?? const <Never>[]).any(
      (source) => source.json == 'adf',
    );
    final colour = offers?.print.color ?? true;
    final failure = state.failure;
    final tone = context.semanticColors.status(AppStatus.success);

    return PopScope(
      // A copy in progress is stopped or finished, not walked away from.
      canPop: !working,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.copyTitle)),
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
              children: switch (state.step) {
                CopyStep.choosing => [
                  const Center(
                    child: AppIllustration(
                      AppIllustrations.printer,
                      height: 148,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.copyLead,
                    style: textTheme.bodyLarge?.copyWith(
                      color: context.colors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.copyCopies,
                                style: textTheme.bodyLarge,
                              ),
                            ),
                            IconButton(
                              tooltip: l10n.copyFewer,
                              onPressed: state.copies > 1
                                  ? () => cubit.setCopies(state.copies - 1)
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            SizedBox(
                              width: AppSpacing.xxl,
                              child: Text(
                                '${state.copies}',
                                style: textTheme.titleMedium,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            IconButton(
                              tooltip: l10n.copyMore,
                              onPressed: state.copies < CopyCubit.maxCopies
                                  ? () => cubit.setCopies(state.copies + 1)
                                  : null,
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                        if (colour)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.copyColor),
                            subtitle: Text(l10n.copyColorBody),
                            value: state.color,
                            onChanged: (on) => cubit.setColor(color: on),
                          ),
                        if (feeder) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(l10n.copyFrom, style: textTheme.bodyLarge),
                          const SizedBox(height: AppSpacing.sm),
                          SegmentedButton<bool>(
                            segments: [
                              ButtonSegment(
                                value: false,
                                label: Text(l10n.scanSourceGlass),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text(l10n.scanSourceFeeder),
                              ),
                            ],
                            selected: {state.fromFeeder},
                            onSelectionChanged: (chosen) =>
                                cubit.setFromFeeder(fromFeeder: chosen.single),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (failure != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    AppNotice(message: CopyWords.failure(l10n, failure)),
                  ],
                  if (state.error != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    AppNotice(message: errorMessage(l10n, state.error)),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  AppSubmitButton(
                    label: l10n.copyAction,
                    onPressed: cubit.copy,
                  ),
                ],
                CopyStep.scanning || CopyStep.printing => [
                  const SizedBox(height: AppSpacing.xxl),
                  const Center(
                    child: AppIllustration(
                      AppIllustrations.printer,
                      height: 180,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    CopyWords.stage(l10n, state),
                    style: textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  OutlinedButton(
                    onPressed: cubit.cancel,
                    child: Text(l10n.copyStop),
                  ),
                ],
                CopyStep.done => [
                  const SizedBox(height: AppSpacing.xxl),
                  Icon(
                    Icons.check_circle_outline,
                    size: 72,
                    color: tone.foreground,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.copyDoneTitle,
                    style: textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.copyDoneBody(state.copies),
                    style: textTheme.bodyLarge?.copyWith(
                      color: context.colors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppSubmitButton(
                    label: l10n.scanDone,
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: cubit.again,
                    child: Text(l10n.copyAgain),
                  ),
                ],
              },
            ),
          ),
        ),
      ),
    );
  }
}
