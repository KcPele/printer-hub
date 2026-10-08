import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/auth/auth.dart';
import 'package:printerhub/errors/error_messages.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/printers/cubit/printer_family_cubit.dart';
import 'package:printerhub/printers/cubit/printers_cubit.dart';
import 'package:printerhub/printers/cubit/recheck_printer_cubit.dart';
import 'package:printerhub/printers/cubit/remove_printer_cubit.dart';
import 'package:printerhub/printers/printer_words.dart';
import 'package:printerhub/printers/widgets/pairing_code_sheet.dart';
import 'package:printerhub/printers/widgets/printer_card.dart';
import 'package:printers_repository/printers_repository.dart';

/// One printer: how it is doing, its supplies, what it can do, and how it
/// connects.
class PrinterDetailPage extends StatelessWidget {
  const new({required this.printerId, super.key});

  final String printerId;

  @override
  Widget build(BuildContext context) {
    final printers = context.read<PrintersCubit>();
    final printer = printers.state.printers
        .where((printer) => printer.id == printerId)
        .firstOrNull;

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => RemovePrinterCubit(printersCubit: printers),
        ),
        BlocProvider(
          create: (_) => RecheckPrinterCubit(printersCubit: printers),
        ),
        BlocProvider(
          // What is known about the printer's family, for the tips.
          lazy: false,
          create: (context) {
            final cubit = PrinterFamilyCubit(
              printersRepository: context.read<PrintersRepository>(),
            );
            unawaited(
              cubit.load(
                manufacturer: printer?.manufacturer,
                model: printer?.model,
              ),
            );
            return cubit;
          },
        ),
      ],
      child: PrinterDetailView(printerId: printerId),
    );
  }
}

class PrinterDetailView extends StatelessWidget {
  const new({required this.printerId, super.key});

  final String printerId;

  Future<void> _confirmRemove(BuildContext context, PrinterRead printer) async {
    final l10n = context.l10n;
    final cubit = context.read<RemovePrinterCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.printerRemoveTitle(printer.friendlyName)),
        content: Text(l10n.printerRemoveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.printerRemoveCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.printerRemoveConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.submit(printerId: printer.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<PrintersCubit>().state;
    final printer = state.printer(printerId);

    if (printer == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              l10n.printerNotFound,
              style: context.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final textTheme = context.textTheme;
    final live = state.live[printer.id];
    final checking = state.checking.contains(printer.id);
    final model = [
      printer.manufacturer,
      printer.model,
    ].whereType<String>().join(' ');
    final alerts = live != null
        ? [for (final alert in live.alerts) (alert.code, alert.severity)]
        : [
            for (final alert in printer.statusDetail.alerts)
              (alert.code, alert.severity.json ?? 'warning'),
          ];
    final supplies = live != null
        ? [
            for (final supply in live.supplies)
              (supply.name, supply.color, supply.levelPercent),
          ]
        : [
            for (final supply in printer.statusDetail.consumables)
              (supply.name, supply.color, supply.levelPercent),
          ];
    final abilities = PrinterWords.abilities(l10n, printer);
    final tips = context.select<PrinterFamilyCubit, List<String>>(
      (cubit) => cubit.state?.setupTips ?? const [],
    );

    final rechecking = context.select<RecheckPrinterCubit, bool>(
      (cubit) => cubit.state.asking,
    );

    return MultiBlocListener(
      listeners: [
        BlocListener<RemovePrinterCubit, SubmitState>(
          listenWhen: (previous, current) =>
              current.succeeded || current.failed,
          listener: (context, removal) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  removal.succeeded
                      ? l10n.printerRemoved(printer.friendlyName)
                      : errorMessage(l10n, removal.error),
                ),
              ),
            );
            if (removal.succeeded) context.pop();
          },
        ),
        BlocListener<RecheckPrinterCubit, RecheckState>(
          listenWhen: (previous, current) => !current.asking,
          listener: (context, recheck) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(switch (recheck.status) {
                  RecheckStatus.noAnswer => l10n.printerRecheckNoAnswer,
                  RecheckStatus.refused => errorMessage(l10n, recheck.error),
                  _ => l10n.printerRecheckDone,
                }),
              ),
            );
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(title: Text(printer.friendlyName)),
        body: RefreshIndicator(
          onRefresh: () => context.read<PrintersCubit>().checkStatus(printer),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              AppSpacing.xxl,
            ),
            children: [
              AppCard(
                child: Column(
                  children: [
                    const AppIllustration(
                      AppIllustrations.printer,
                      height: 148,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (model.isNotEmpty)
                      Text(
                        model,
                        style: textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                    if (printer.location != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        printer.location!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: context.colors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    PrinterStatusPill(printer: printer),
                  ],
                ),
              ),
              for (final (code, severity) in alerts) ...[
                const SizedBox(height: AppSpacing.md),
                AppNotice(
                  status: severity == 'error'
                      ? AppStatus.error
                      : AppStatus.warning,
                  message: PrinterWords.alert(l10n, code),
                ),
              ],
              if (supplies.isNotEmpty)
                _Section(
                  title: l10n.printerSupplies,
                  child: Column(
                    children: [
                      for (final (index, (name, color, percent))
                          in supplies.indexed) ...[
                        if (index > 0) const SizedBox(height: AppSpacing.lg),
                        SupplyLevelBar(
                          toner: PrinterWords.toner(color),
                          label: name,
                          valueLabel: percent == null
                              ? l10n.printerSupplyUnknown
                              : l10n.printerSupplyPercent(percent),
                          level: percent == null ? null : percent / 100,
                        ),
                      ],
                    ],
                  ),
                ),
              if (abilities.isNotEmpty)
                _Section(
                  title: l10n.printerAbilities,
                  child: Column(
                    children: [
                      for (final ability in abilities)
                        _Line(icon: Icons.check_circle, text: ability),
                    ],
                  ),
                ),
              if (printer.connections.isNotEmpty)
                _Section(
                  title: l10n.printerConnections,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final connection in printer.connections)
                        _Line(
                          icon: connection.type == ConnectionType.escl
                              ? Icons.document_scanner_outlined
                              : Icons.print_outlined,
                          text:
                              '${PrinterWords.connection(l10n, connection)}\n'
                              '${PrinterWords.health(l10n, connection).label}',
                        ),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton(
                          onPressed: () => context.push(
                            AppRoutes.printerConnections(printer.id),
                          ),
                          child: Text(l10n.connectionsManage),
                        ),
                      ),
                    ],
                  ),
                ),
              if (tips.isNotEmpty)
                _Section(
                  title: l10n.printerTips,
                  child: Column(
                    children: [
                      for (final tip in tips)
                        _Line(icon: Icons.lightbulb_outline, text: tip),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              if (printer.capabilities?.print.supported ?? true) ...[
                AppSubmitButton(
                  label: l10n.printAction,
                  onPressed: () => context.push(AppRoutes.printOn(printer.id)),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              OutlinedButton.icon(
                onPressed: checking
                    ? null
                    : () => context.read<PrintersCubit>().checkStatus(printer),
                icon: checking
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(l10n.printerCheck),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: rechecking
                    ? null
                    : () =>
                          context.read<RecheckPrinterCubit>().recheck(printer),
                icon: const Icon(Icons.manage_search),
                label: Text(l10n.printerRecheck),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => showPairingCode(context, printer),
                icon: const Icon(Icons.qr_code_2),
                label: Text(l10n.printerShare),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: context.semanticColors.error.foreground,
                ),
                onPressed: () => _confirmRemove(context, printer),
                child: Text(l10n.printerRemove),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const new({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xl),
        Text(title, style: context.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        AppCard(child: child),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const new({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.colors.emphasis),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: context.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
