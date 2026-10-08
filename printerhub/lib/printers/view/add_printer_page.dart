import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/printers/cubit/add_printer_cubit.dart';
import 'package:printerhub/printers/cubit/nearby_cubits.dart';
import 'package:printerhub/printers/cubit/printers_cubit.dart';
import 'package:printerhub/printers/finders.dart';
import 'package:printerhub/printers/widgets/add_printer_steps.dart';
import 'package:printerhub/session/session.dart';
import 'package:printers_repository/printers_repository.dart';

/// Adds a printer: find it one way or another, see what it can do, name it.
class AddPrinterPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final finders = context.read<PrinterFinders>();

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) {
            final cubit = AddPrinterCubit(
              printersRepository: context.read<PrintersRepository>(),
              finders: finders,
              organizationId: context
                  .read<SessionCubit>()
                  .state
                  .organization!
                  .id,
            );
            unawaited(cubit.start());
            return cubit;
          },
        ),
        BlocProvider(
          // Looking starts as the screen opens, so by the time it is read
          // the nearby printers are usually already listed.
          lazy: false,
          create: (_) => NearbyPrintersCubit(discovery: finders.network),
        ),
      ],
      child: const AddPrinterView(),
    );
  }
}

class AddPrinterView extends StatelessWidget {
  const new({super.key});

  /// The steps that are a screen of their own, from which Back returns to
  /// the list of ways and not out of adding a printer.
  static const Set<AddPrinterStep> _inner = {
    AddPrinterStep.address,
    AddPrinterStep.qr,
    AddPrinterStep.wifiDirect,
    AddPrinterStep.bluetooth,
    AddPrinterStep.password,
    AddPrinterStep.found,
  };

  Future<void> _opened(BuildContext context, PrinterRead printer) async {
    final session = context.read<SessionCubit>();
    final printers = context.read<PrintersCubit>();
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final message = context.l10n.pairingOpened(printer.friendlyName);

    // A code can name a printer in another of the user's workspaces.
    final workspace = session.state.organizations
        .where((item) => item.id == printer.organizationId)
        .firstOrNull;
    if (workspace != null && workspace != session.state.organization) {
      await session.selectWorkspace(workspace);
    }
    await printers.load();
    messenger.showSnackBar(SnackBar(content: Text(message)));
    router.go(AppRoutes.printer(printer.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<AddPrinterCubit>();
    final step = context.select<AddPrinterCubit, AddPrinterStep>(
      (cubit) => cubit.state.step,
    );
    final isInner = _inner.contains(step);

    return BlocListener<AddPrinterCubit, AddPrinterState>(
      listenWhen: (previous, current) =>
          previous.step != current.step &&
          (current.step == AddPrinterStep.added ||
              current.step == AddPrinterStep.paired),
      listener: (context, state) {
        final printer = state.printer!;
        if (state.step == AddPrinterStep.paired) {
          unawaited(_opened(context, printer));
          return;
        }
        context.read<PrintersCubit>().added(printer, state.device!.status);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.addPrinterAdded(printer.friendlyName))),
        );
        context.pop();
      },
      child: PopScope(
        // Back leaves an inner step for the list of ways first.
        canPop: !isInner,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) cubit.back();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(switch (step) {
              AddPrinterStep.qr => l10n.qrTitle,
              AddPrinterStep.wifiDirect => l10n.wifiDirectTitle,
              AddPrinterStep.bluetooth => l10n.bluetoothTitle,
              _ => l10n.addPrinterTitle,
            }),
          ),
          body: SafeArea(
            child: switch (step) {
              AddPrinterStep.ways => const WaysStep(),
              AddPrinterStep.address => const AddressStep(),
              AddPrinterStep.qr => const QrStep(),
              AddPrinterStep.wifiDirect => const WifiDirectStep(),
              AddPrinterStep.bluetooth => const BluetoothStep(),
              AddPrinterStep.password => const PasswordStep(),
              AddPrinterStep.searching ||
              AddPrinterStep.paired => const SearchingStep(),
              AddPrinterStep.found ||
              AddPrinterStep.saving ||
              AddPrinterStep.added => const FoundStep(),
            },
          ),
        ),
      ),
    );
  }
}
