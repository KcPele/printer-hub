import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/notifications/notifications.dart';
import 'package:printerhub/printers/printers.dart';
import 'package:printerhub/printers/widgets/printer_choice_sheet.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/session/session.dart';
import 'package:printerhub/tools/tools.dart';
import 'package:printerhub/workspace/cubit/features_cubit.dart';
import 'package:printers_repository/printers_repository.dart';

/// Home: the workspace's printers at a glance and what can be done right
/// now. Before there are any printers, it says what the app is for, offers
/// to add one, and still offers what the phone can do on its own.
class HomePage extends StatelessWidget {
  const new({super.key});

  /// How many printers Home shows before "See all".
  static const int _shown = 2;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final printers = context.select<PrintersCubit, List<PrinterRead>>(
      (cubit) => cubit.state.printers,
    );
    final unread = context.watch<UnreadCubit>().state;
    final needsVerification = context.select<SessionCubit, bool>(
      (cubit) => cubit.state.user?.emailVerified == false,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appName),
        actions: [
          IconButton(
            tooltip: l10n.notificationsTitle,
            onPressed: () => context.push(AppRoutes.notifications),
            icon: Badge.count(
              count: unread,
              isLabelVisible: unread > 0,
              child: const Icon(Icons.notifications_none),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.xxl,
        ),
        children: [
          if (needsVerification) ...[
            AppNotice(
              status: AppStatus.warning,
              message: l10n.verifyBanner,
              action: TextButton(
                onPressed: () => context.push(AppRoutes.verifyEmail),
                child: Text(l10n.verifyTitle),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (printers.isEmpty) ...[
            const _Welcome(),
            const SizedBox(height: AppSpacing.xxl),
            Text(l10n.homePhoneTitle, style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            const _Actions(hasPrinters: false),
            const SizedBox(height: AppSpacing.xxl),
            const _Tools(),
            const SizedBox(height: AppSpacing.xxl),
            const _GettingStarted(),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Text(l10n.homePrinters, style: textTheme.titleLarge),
                ),
                TextButton(
                  onPressed: () => context.go(AppRoutes.printers),
                  child: Text(l10n.homeSeeAll),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final printer in printers.take(_shown)) ...[
              PrinterCard(
                printer: printer,
                onTap: () => context.go(AppRoutes.printer(printer.id)),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.homeActionsTitle, style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            const _Actions(hasPrinters: true),
            const SizedBox(height: AppSpacing.xxl),
            const _Tools(),
          ],
        ],
      ),
    );
  }
}

/// What a person with no printers sees first: what the app is for, and
/// the way to begin.
class _Welcome extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: AppIllustration(AppIllustrations.printer, width: 200),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.homeHeroTitle,
            style: textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.homeHeroBody,
            style: textTheme.bodyMedium?.copyWith(
              color: context.colors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppSubmitButton(
            label: l10n.homeAddPrinter,
            onPressed: () => context.go(AppRoutes.addPrinter),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: () => context.go(AppRoutes.catalogue),
            child: Text(l10n.homeSeeCatalogue),
          ),
        ],
      ),
    );
  }
}

/// What can be done from Home, two to a row. Only what works is shown:
/// the camera where the phone has one and the workspace has it switched
/// on, printing where there is a printer that prints.
class _Actions extends StatelessWidget {
  const new({required this.hasPrinters});

  final bool hasPrinters;

  Future<void> _print(BuildContext context) async {
    final router = GoRouter.of(context);
    final printer = await choosePrinter(context);
    if (printer != null) router.go(AppRoutes.printOn(printer.id));
  }

  Future<void> _copy(BuildContext context) async {
    final router = GoRouter.of(context);
    final printer = await choosePrinter(context, andScan: true);
    if (printer != null) router.go(AppRoutes.copyOn(printer.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final camera =
        context.read<PageCamera>().available &&
        context.select<FeaturesCubit, bool>(
          (features) => features.enabled('camera_scan'),
        );
    final prints = hasPrinters && printersThatPrint(context).isNotEmpty;
    final copies =
        hasPrinters && printersThatPrint(context, andScan: true).isNotEmpty;

    final tiles = [
      if (prints)
        ToolTile(
          icon: Icons.print_outlined,
          title: l10n.homeActionPrint,
          body: l10n.homeActionPrintBody,
          onTap: () => _print(context),
        ),
      if (copies)
        ToolTile(
          icon: Icons.copy_outlined,
          title: l10n.homeActionCopy,
          body: l10n.homeActionCopyBody,
          onTap: () => _copy(context),
        ),
      if (camera)
        ToolTile(
          icon: Icons.photo_camera_outlined,
          title: l10n.homeActionScan,
          body: l10n.homeActionScanBody,
          onTap: () => context.push(AppRoutes.scan),
        ),
      ToolTile(
        icon: Icons.folder_outlined,
        title: l10n.homeActionDocuments,
        body: l10n.homeActionDocumentsBody,
        onTap: () => context.go(AppRoutes.documents),
      ),
      if (hasPrinters)
        ToolTile(
          icon: Icons.add,
          title: l10n.homeAddPrinter,
          body: l10n.homeActionAddBody,
          onTap: () => context.go(AppRoutes.addPrinter),
        ),
    ];

    return ToolGrid(tiles: tiles);
  }
}

/// The first few tools, and the way to all of them.
class _Tools extends StatelessWidget {
  const new();

  /// How many tools Home shows before "See all".
  static const int _shown = 4;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tiles = toolTiles(context, withScan: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(l10n.toolsTitle, style: context.textTheme.titleLarge),
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.tools),
              child: Text(l10n.toolsSeeAll),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ToolGrid(tiles: tiles.take(_shown).toList()),
      ],
    );
  }
}

/// The three steps from no printer to a finished job.
class _GettingStarted extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.homeStartTitle, style: context.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            children: [
              _Step(
                number: 1,
                title: l10n.homeStepAddTitle,
                body: l10n.homeStepAddBody,
              ),
              const SizedBox(height: AppSpacing.xl),
              _Step(
                number: 2,
                title: l10n.homeStepUseTitle,
                body: l10n.homeStepUseBody,
              ),
              const SizedBox(height: AppSpacing.xl),
              _Step(
                number: 3,
                title: l10n.homeStepTrackTitle,
                body: l10n.homeStepTrackBody,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const new({required this.number, required this.title, required this.body});

  final int number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.primary,
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(
            dimension: AppSpacing.xxl,
            child: Center(
              child: Text(
                '$number',
                style: textTheme.labelLarge?.copyWith(color: colors.onPrimary),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                body,
                style: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
