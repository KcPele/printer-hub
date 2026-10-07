import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/errors/error_messages.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/printers/cubit/printers_cubit.dart';
import 'package:printerhub/printers/widgets/printer_card.dart';

/// The workspace's printers.
class PrintersPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<PrintersCubit>().state;
    final printers = state.printers;

    final Widget body;
    if (printers.isNotEmpty) {
      body = RefreshIndicator(
        onRefresh: context.read<PrintersCubit>().load,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            // Room for the button that floats over the end of the list.
            AppSpacing.xxxl * 2,
          ),
          itemCount: printers.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) => PrinterCard(
            printer: printers[index],
            onTap: () => context.push(AppRoutes.printer(printers[index].id)),
          ),
        ),
      );
    } else if (state.status == PrintersStatus.failure) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppNotice(message: errorMessage(l10n, state.error)),
              const SizedBox(height: AppSpacing.xl),
              AppSubmitButton(
                label: l10n.printersRetry,
                onPressed: context.read<PrintersCubit>().load,
              ),
            ],
          ),
        ),
      );
    } else if (state.status == PrintersStatus.ready) {
      body = EmptyState(
        illustration: AppIllustrations.printer,
        title: l10n.printersEmptyTitle,
        message: l10n.printersEmptyBody,
        action: FilledButton.icon(
          onPressed: () => context.push(AppRoutes.addPrinter),
          icon: const Icon(Icons.add),
          label: Text(l10n.printersAdd),
        ),
      );
    } else {
      body = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navPrinters)),
      body: body,
      floatingActionButton: printers.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.addPrinter),
              icon: const Icon(Icons.add),
              label: Text(l10n.printersAdd),
            ),
    );
  }
}
