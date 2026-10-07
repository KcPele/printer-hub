import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/errors/error_messages.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/printers/cubit/add_printer_cubit.dart';
import 'package:printerhub/printers/cubit/printers_cubit.dart';
import 'package:printerhub/printers/printer_words.dart';
import 'package:printerhub/session/session.dart';
import 'package:printers_repository/printers_repository.dart';

/// Adds a printer: find it by its address, see what it can do, name it.
class AddPrinterPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AddPrinterCubit(
        printersRepository: context.read<PrintersRepository>(),
        organizationId: context.read<SessionCubit>().state.organization!.id,
      ),
      child: const AddPrinterView(),
    );
  }
}

class AddPrinterView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final step = context.select<AddPrinterCubit, AddPrinterStep>(
      (cubit) => cubit.state.step,
    );

    return BlocListener<AddPrinterCubit, AddPrinterState>(
      listenWhen: (previous, current) => current.step == AddPrinterStep.added,
      listener: (context, state) {
        final printer = state.printer!;
        context.read<PrintersCubit>().added(printer, state.device!.status);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.addPrinterAdded(printer.friendlyName))),
        );
        context.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.addPrinterTitle)),
        body: SafeArea(
          child: switch (step) {
            AddPrinterStep.address => const _AddressStep(),
            AddPrinterStep.searching => const _SearchingStep(),
            AddPrinterStep.found ||
            AddPrinterStep.saving ||
            AddPrinterStep.added => const _FoundStep(),
          },
        ),
      ),
    );
  }
}

const EdgeInsets _stepPadding = EdgeInsets.fromLTRB(
  AppSpacing.page,
  AppSpacing.sm,
  AppSpacing.page,
  AppSpacing.xl,
);

class _AddressStep extends StatefulWidget {
  const new();

  @override
  State<_AddressStep> createState() => _AddressStepState();
}

class _AddressStepState extends State<_AddressStep> {
  // Starts with the address last tried, so a typo can be corrected.
  late final TextEditingController _address = TextEditingController(
    text: context.read<AddPrinterCubit>().state.address,
  );

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    FocusScope.of(context).unfocus();
    await context.read<AddPrinterCubit>().find(_address.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final failure = context.select<AddPrinterCubit, ProbeFailureKind?>(
      (cubit) => cubit.state.probeFailure,
    );

    return SingleChildScrollView(
      padding: _stepPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: AppIllustration(AppIllustrations.printer, height: 168),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.addPrinterBody,
            style: context.textTheme.bodyLarge?.copyWith(
              color: context.colors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _address,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _find(),
                  decoration: InputDecoration(
                    labelText: l10n.addPrinterAddress,
                    hintText: l10n.addPrinterAddressHint,
                    prefixIcon: const Icon(Icons.router_outlined),
                  ),
                ),
                if (failure != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppNotice(
                    message: switch (failure) {
                      ProbeFailureKind.invalidAddress => l10n.addPrinterInvalid,
                      ProbeFailureKind.unreachable =>
                        l10n.addPrinterUnreachable,
                      ProbeFailureKind.notAPrinter =>
                        l10n.addPrinterNotAPrinter,
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                AppSubmitButton(label: l10n.addPrinterFind, onPressed: _find),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchingStep extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIllustration(AppIllustrations.printer, height: 168),
            const SizedBox(height: AppSpacing.xl),
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              context.l10n.addPrinterSearching,
              style: context.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FoundStep extends StatefulWidget {
  const new();

  @override
  State<_FoundStep> createState() => _FoundStepState();
}

class _FoundStepState extends State<_FoundStep> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: context.read<AddPrinterCubit>().state.device!.displayName,
  );
  final _location = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await context.read<AddPrinterCubit>().save(
      name: _name.text.trim(),
      location: _location.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final state = context.watch<AddPrinterCubit>().state;
    final device = state.device!;

    return SingleChildScrollView(
      padding: _stepPadding,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: AppIllustration(AppIllustrations.printer, height: 148),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.addPrinterFound,
              style: textTheme.labelLarge?.copyWith(
                color: context.colors.emphasis,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              device.displayName,
              style: textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              tone: AppCardTone.muted,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  for (final feature in PrinterWords.features(l10n, device))
                    _Feature(feature),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? l10n.addPrinterNameRequired
                        : null,
                    decoration: InputDecoration(
                      labelText: l10n.addPrinterName,
                      prefixIcon: const Icon(Icons.print_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _location,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _save(),
                    decoration: InputDecoration(
                      labelText: l10n.addPrinterLocation,
                      hintText: l10n.addPrinterLocationHint,
                      prefixIcon: const Icon(Icons.place_outlined),
                    ),
                  ),
                  if (state.error != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    AppNotice(message: errorMessage(l10n, state.error)),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  AppSubmitButton(
                    label: l10n.addPrinterSave,
                    loading: state.step == AddPrinterStep.saving,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: context.read<AddPrinterCubit>().startOver,
              child: Text(l10n.addPrinterDifferent),
            ),
          ],
        ),
      ),
    );
  }
}

/// One thing the device can do, with a tick.
class _Feature extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 20, color: context.colors.emphasis),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: context.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
