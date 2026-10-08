import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/errors/error_messages.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/print/cubit/print_cubit.dart';
import 'package:printerhub/print/documents.dart';
import 'package:printerhub/print/print_words.dart';
import 'package:printerhub/print/widgets/print_options.dart';
import 'package:printerhub/printers/cubit/printers_cubit.dart';
import 'package:printerhub/session/session.dart';
import 'package:printers_repository/printers_repository.dart';

/// Prints a document on one printer: choose it, say how, and follow it.
class PrintPage extends StatelessWidget {
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

    return BlocProvider(
      create: (context) => PrintCubit(
        printersRepository: context.read<PrintersRepository>(),
        jobsRepository: context.read<JobsRepository>(),
        documents: context.read<PrintDocuments>(),
        organizationId: context.read<SessionCubit>().state.organization!.id,
        printer: printer,
      ),
      child: PrintView(printer: printer),
    );
  }
}

class PrintView extends StatelessWidget {
  const new({required this.printer, super.key});

  final PrinterRead printer;

  @override
  Widget build(BuildContext context) {
    final step = context.select<PrintCubit, PrintStep>(
      (cubit) => cubit.state.step,
    );

    return PopScope(
      // A print in progress is cancelled or finished, not walked away from.
      canPop: step != PrintStep.printing,
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.printTitle)),
        body: SafeArea(
          child: switch (step) {
            PrintStep.choosing || PrintStep.reading => const _Choose(),
            PrintStep.ready => _Ready(printer: printer),
            PrintStep.printing => const _Printing(),
            PrintStep.finished => const _Finished(),
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
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<PrintCubit>().state;
    final problem = switch (state.problem) {
      PrintProblem.unsupportedFile => l10n.printUnsupportedFile,
      PrintProblem.unreadableFile => l10n.printUnreadableFile,
      null => null,
    };

    return SingleChildScrollView(
      padding: _padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: AppIllustration(AppIllustrations.phonePrint, height: 200),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.printChooseTitle,
            style: context.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            state.step == PrintStep.reading
                ? l10n.printReading
                : l10n.printChooseBody,
            style: context.textTheme.bodyLarge?.copyWith(
              color: context.colors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
          if (problem != null) ...[
            const SizedBox(height: AppSpacing.lg),
            AppNotice(message: problem),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppSubmitButton(
            label: l10n.printChooseAction,
            loading: state.step == PrintStep.reading,
            onPressed: context.read<PrintCubit>().choose,
          ),
        ],
      ),
    );
  }
}

class _Ready extends StatefulWidget {
  const new({required this.printer});

  final PrinterRead printer;

  @override
  State<_Ready> createState() => _ReadyState();
}

class _ReadyState extends State<_Ready> {
  final _form = GlobalKey<FormState>();

  Future<void> _print() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await context.read<PrintCubit>().print();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final cubit = context.read<PrintCubit>();
    final state = context.watch<PrintCubit>().state;
    final document = state.document!;
    final preview = state.preview!;
    final picture = preview.firstPage;

    return SingleChildScrollView(
      padding: _padding,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: context.shapes.chipRadius,
                    child: SizedBox(
                      width: 72,
                      height: 96,
                      child: picture == null
                          ? ColoredBox(
                              color: context.colors.surfaceMuted,
                              child: const Icon(Icons.description_outlined),
                            )
                          : Image.memory(
                              picture,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.name,
                          style: textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          l10n.printPageCount(preview.pageCount),
                          style: textTheme.bodyMedium?.copyWith(
                            color: context.colors.textMuted,
                          ),
                        ),
                        TextButton(
                          onPressed: cubit.choose,
                          child: Text(l10n.printChooseAnother),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(l10n.printOptionsTitle, style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: PrintOptions(
                printer: widget.printer,
                pageCount: preview.pageCount,
              ),
            ),
            if (state.error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppNotice(message: errorMessage(l10n, state.error)),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppSubmitButton(label: l10n.printAction, onPressed: _print),
          ],
        ),
      ),
    );
  }
}

class _Printing extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final progress = context.select<PrintCubit, PrintProgress?>(
      (cubit) => cubit.state.progress,
    );
    final stopped = progress?.stage == PrintStage.attention;

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
          if (!stopped) const Center(child: CircularProgressIndicator()),
          const SizedBox(height: AppSpacing.lg),
          Text(
            PrintWords.stage(l10n, progress),
            style: textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          if (stopped && progress != null) ...[
            const SizedBox(height: AppSpacing.lg),
            for (final reason in PrintWords.attention(l10n, progress)) ...[
              AppNotice(status: AppStatus.warning, message: reason),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
          if (progress?.fellBack ?? false) ...[
            const SizedBox(height: AppSpacing.lg),
            AppNotice(status: AppStatus.info, message: l10n.printFellBack),
          ],
          const SizedBox(height: AppSpacing.xxl),
          OutlinedButton(
            onPressed: context.read<PrintCubit>().cancel,
            child: Text(l10n.printCancel),
          ),
        ],
      ),
    );
  }
}

class _Finished extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final cubit = context.read<PrintCubit>();
    final state = context.watch<PrintCubit>().state;
    final progress = state.progress;

    final (status, icon, title, body) = switch (progress?.stage) {
      _ when state.handedToSystem => (
        AppStatus.info,
        Icons.ios_share,
        l10n.printSystemTitle,
        l10n.printSystemBody,
      ),
      PrintStage.completed => (
        AppStatus.success,
        Icons.check_circle_outline,
        l10n.printDoneTitle,
        l10n.printDoneBody,
      ),
      PrintStage.cancelled => (
        AppStatus.neutral,
        Icons.cancel_outlined,
        l10n.printCancelledTitle,
        l10n.printCancelledBody,
      ),
      PrintStage.unknown => (
        AppStatus.warning,
        Icons.help_outline,
        l10n.printUnknownTitle,
        PrintWords.failure(l10n, progress),
      ),
      PrintStage.failed => (
        AppStatus.error,
        Icons.error_outline,
        l10n.printFailedTitle,
        PrintWords.failure(l10n, progress),
      ),
      // The printer still has it, and the app has stopped watching.
      _ => (
        AppStatus.info,
        Icons.hourglass_bottom,
        l10n.printLeftTitle,
        l10n.printLeftBody,
      ),
    };
    final worked =
        state.handedToSystem ||
        progress?.stage == PrintStage.completed ||
        progress?.stage == PrintStage.printing;

    return SingleChildScrollView(
      padding: _padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Icon(
            icon,
            size: 72,
            color: context.semanticColors.status(status).foreground,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            style: textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: textTheme.bodyLarge?.copyWith(
              color: context.colors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppSubmitButton(label: l10n.printDone, onPressed: context.pop),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: cubit.again,
            child: Text(worked ? l10n.printAgain : l10n.printTryAgain),
          ),
          if (state.canUseSystemPrint) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: cubit.useSystemPrint,
              icon: const Icon(Icons.ios_share),
              label: Text(l10n.printUseSystem),
            ),
          ],
        ],
      ),
    );
  }
}
