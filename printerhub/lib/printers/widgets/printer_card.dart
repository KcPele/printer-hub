import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/printers/cubit/printers_cubit.dart';
import 'package:printerhub/printers/printer_words.dart';
import 'package:printers_repository/printers_repository.dart';

/// A printer in a list: its picture, its name, and how it is doing.
class PrinterCard extends StatelessWidget {
  const new({required this.printer, this.onTap, super.key});

  final PrinterRead printer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final model = [
      printer.manufacturer,
      printer.model,
    ].whereType<String>().join(' ');

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          const AppIllustration(AppIllustrations.printer, width: 76),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  printer.friendlyName,
                  style: textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (model.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    model,
                    style: textTheme.bodySmall?.copyWith(
                      color: context.colors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                PrinterStatusPill(printer: printer),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right, color: context.colors.textMuted),
        ],
      ),
    );
  }
}

/// How a printer is doing, kept up to date as it is asked.
class PrinterStatusPill extends StatelessWidget {
  const new({required this.printer, super.key});

  final PrinterRead printer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<PrintersCubit>().state;
    final live = state.live[printer.id];

    // The first check of a printer has nothing older to show.
    if (live == null && state.checking.contains(printer.id)) {
      return StatusPill(
        status: AppStatus.neutral,
        label: l10n.printerStatusChecking,
      );
    }
    final standing = PrinterWords.standing(l10n, printer, live: live);
    return StatusPill(status: standing.status, label: standing.label);
  }
}
