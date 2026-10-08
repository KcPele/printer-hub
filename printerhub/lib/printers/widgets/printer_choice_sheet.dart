import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/printers/cubit/printers_cubit.dart';
import 'package:printerhub/printers/widgets/printer_card.dart';
import 'package:printers_repository/printers_repository.dart';

/// The workspace's printers that can print.
List<PrinterRead> printersThatPrint(BuildContext context) => [
  for (final printer in context.read<PrintersCubit>().state.printers)
    if (printer.capabilities?.print.supported ?? true) printer,
];

/// The printer to print on, for a document that arrives without one: a
/// kept document, a file another app shared.
///
/// With one printer there is nothing to ask. With several the person
/// chooses. Null when there is none, or they chose none.
Future<PrinterRead?> choosePrinter(BuildContext context) async {
  final printers = printersThatPrint(context);
  if (printers.length < 2) return printers.firstOrNull;

  final cubit = context.read<PrintersCubit>();
  return await showModalBottomSheet<PrinterRead>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => BlocProvider.value(
      value: cubit,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                sheetContext.l10n.printerChoiceTitle,
                style: sheetContext.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              for (final printer in printers) ...[
                PrinterCard(
                  printer: printer,
                  onTap: () => Navigator.of(sheetContext).pop(printer),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
