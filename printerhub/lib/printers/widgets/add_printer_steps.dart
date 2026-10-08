import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printer_discovery/printer_discovery.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/auth/widgets/password_field.dart';
import 'package:printerhub/errors/error_messages.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/printers/cubit/add_printer_cubit.dart';
import 'package:printerhub/printers/cubit/nearby_cubits.dart';
import 'package:printerhub/printers/finders.dart';
import 'package:printerhub/printers/printer_words.dart';
import 'package:printers_repository/printers_repository.dart';

const EdgeInsets _stepPadding = EdgeInsets.fromLTRB(
  AppSpacing.page,
  AppSpacing.sm,
  AppSpacing.page,
  AppSpacing.xl,
);

class AddressStep extends StatefulWidget {
  const new({super.key});

  @override
  State<AddressStep> createState() => _AddressStepState();
}

class _AddressStepState extends State<AddressStep> {
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
                const StepMessages(),
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

/// The printer asked who is printing: a user name and a password, which
/// are saved with the printer for the rest of the workspace.
class PasswordStep extends StatefulWidget {
  const new({super.key});

  @override
  State<PasswordStep> createState() => _PasswordStepState();
}

class _PasswordStepState extends State<PasswordStep> {
  final _form = GlobalKey<FormState>();
  final _userName = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _userName.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await context.read<AddPrinterCubit>().signIn(
      userName: _userName.text.trim(),
      password: _password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      padding: _stepPadding,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: AppIllustration(AppIllustrations.private, height: 168),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.printerPasswordTitle,
              style: context.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.printerPasswordBody,
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
                  TextFormField(
                    controller: _userName,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? l10n.printerPasswordUserNeeded
                        : null,
                    decoration: InputDecoration(
                      labelText: l10n.printerPasswordUser,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PasswordField(
                    controller: _password,
                    label: l10n.printerPasswordPassword,
                    validator: (value) => (value ?? '').isEmpty
                        ? l10n.printerPasswordNeeded
                        : null,
                    onSubmitted: _connect,
                  ),
                  const StepMessages(),
                  const SizedBox(height: AppSpacing.lg),
                  AppSubmitButton(
                    label: l10n.printerPasswordAction,
                    onPressed: _connect,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchingStep extends StatelessWidget {
  const new({super.key});

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

class FoundStep extends StatefulWidget {
  const new({super.key});

  @override
  State<FoundStep> createState() => _FoundStepState();
}

class _FoundStepState extends State<FoundStep> {
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
                  const StepMessages(),
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
              onPressed: context.read<AddPrinterCubit>().back,
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

/// Why the last attempt on this step did not find a printer, when it did
/// not. Every step that can fail shows it the same way.
class StepMessages extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<AddPrinterCubit>().state;

    final message = switch (state) {
      AddPrinterState(probeFailure: ProbeFailureKind.invalidAddress) =>
        l10n.addPrinterInvalid,
      AddPrinterState(probeFailure: ProbeFailureKind.unreachable) =>
        l10n.addPrinterUnreachable,
      AddPrinterState(probeFailure: ProbeFailureKind.notAPrinter) =>
        l10n.addPrinterNotAPrinter,
      AddPrinterState(probeFailure: ProbeFailureKind.wrongPassword) =>
        l10n.printerPasswordWrong,
      // Only reported once a password has been given and could not be sent.
      AddPrinterState(probeFailure: ProbeFailureKind.needsPassword) =>
        l10n.printerPasswordNeedsSecure,
      AddPrinterState(notice: AddPrinterNotice.codeNotRecognised) =>
        l10n.qrUnrecognised,
      AddPrinterState(notice: AddPrinterNotice.nfcNothing) => l10n.nfcNothing,
      AddPrinterState(notice: AddPrinterNotice.nfcFailed) => l10n.nfcFailed,
      AddPrinterState(notice: AddPrinterNotice.notOnPrinterNetwork) =>
        l10n.wifiDirectNoNetwork,
      AddPrinterState(
        notice: AddPrinterNotice.seenButNotOnNetwork,
        :final noticeSubject,
      ) =>
        l10n.bluetoothNotOnNetwork(noticeSubject ?? ''),
      AddPrinterState(:final error?) => errorMessage(l10n, error),
      _ => null,
    };
    if (message == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: AppNotice(message: message),
    );
  }
}

/// Where adding a printer starts: the printers found on the network, and
/// the other ways to reach one.
class WaysStep extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final cubit = context.read<AddPrinterCubit>();
    final state = context.watch<AddPrinterCubit>().state;
    final nearby = context.watch<NearbyPrintersCubit>().state;

    return ListView(
      padding: _stepPadding,
      children: [
        Text(l10n.waysNearby, style: textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        if (nearby.isEmpty)
          AppCard(
            tone: AppCardTone.muted,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.waysLooking, style: textTheme.titleSmall),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        l10n.waysNearbyHint,
                        style: textTheme.bodySmall?.copyWith(
                          color: context.colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          for (final device in nearby) ...[
            _NearbyTile(device: device, onTap: () => cubit.findNearby(device)),
            const SizedBox(height: AppSpacing.md),
          ],
        const StepMessages(),
        const SizedBox(height: AppSpacing.xl),
        Text(l10n.waysOther, style: textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            children: [
              _Way(
                icon: Icons.router_outlined,
                title: l10n.waysAddress,
                body: l10n.waysAddressBody,
                onTap: () => cubit.choose(AddPrinterStep.address),
              ),
              _Way(
                icon: Icons.qr_code_scanner,
                title: l10n.waysQr,
                body: l10n.waysQrBody,
                onTap: () => cubit.choose(AddPrinterStep.qr),
              ),
              if (state.readingNfc)
                _Way(
                  icon: Icons.nfc,
                  title: l10n.nfcWaiting,
                  body: l10n.nfcCancel,
                  onTap: cubit.cancelNfc,
                  busy: true,
                )
              else
                _Way(
                  icon: Icons.nfc,
                  title: l10n.waysNfc,
                  body: state.nfcAvailable
                      ? l10n.waysNfcBody
                      : l10n.waysNfcUnavailable,
                  onTap: state.nfcAvailable ? cubit.readNfc : null,
                ),
              _Way(
                icon: Icons.wifi_tethering,
                title: l10n.waysWifiDirect,
                body: l10n.waysWifiDirectBody,
                onTap: () => cubit.choose(AddPrinterStep.wifiDirect),
              ),
              _Way(
                icon: Icons.bluetooth_searching,
                title: l10n.waysBluetooth,
                body: state.bluetoothAvailable
                    ? l10n.waysBluetoothBody
                    : l10n.waysBluetoothUnavailable,
                onTap: state.bluetoothAvailable
                    ? () => cubit.choose(AddPrinterStep.bluetooth)
                    : null,
              ),
              _Way(
                icon: Icons.menu_book_outlined,
                title: l10n.waysCatalogue,
                body: l10n.waysCatalogueBody,
                onTap: () => context.push(AppRoutes.catalogue),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A printer found on the network.
class _NearbyTile extends StatelessWidget {
  const new({required this.device, required this.onTap});

  final NearbyDevice device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final abilities = [
      if (device.prints) l10n.waysPrints,
      if (device.scans) l10n.waysScans,
    ].join(' · ');

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          const AppIllustration(AppIllustrations.printer, width: 60),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.model ?? device.name,
                  style: textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  [
                    abilities,
                    device.host,
                  ].where((t) => t.isNotEmpty).join('  '),
                  style: textTheme.bodySmall?.copyWith(
                    color: context.colors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.colors.textMuted),
        ],
      ),
    );
  }
}

/// One way to connect. Greyed, with the reason, when the phone cannot use
/// it.
class _Way extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: onTap != null,
      leading: busy
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Icon(icon),
      title: Text(title),
      subtitle: Text(body),
      trailing: onTap == null || busy
          ? null
          : Icon(Icons.chevron_right, color: context.colors.textMuted),
      onTap: onTap,
    );
  }
}

/// The camera, looking for a code on the printer or on another phone.
class QrStep extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<AddPrinterCubit>();

    return SingleChildScrollView(
      padding: _stepPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.qrBody,
            style: context.textTheme.bodyLarge?.copyWith(
              color: context.colors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: context.shapes.cardRadius,
              child: ColoredBox(
                color: context.colors.inverseSurface,
                child: context.read<PrinterFinders>().qrScanner(cubit.useCode),
              ),
            ),
          ),
          const StepMessages(),
        ],
      ),
    );
  }
}

/// The steps for joining the printer's own Wi-Fi, for when there is no
/// network to share.
class WifiDirectStep extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final network = context.select<AddPrinterCubit, WifiNetworkCode?>(
      (cubit) => cubit.state.wifi,
    );

    return SingleChildScrollView(
      padding: _stepPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              children: [
                _Numbered(1, l10n.wifiDirectStep1),
                const SizedBox(height: AppSpacing.xl),
                _Numbered(
                  2,
                  network == null
                      ? l10n.wifiDirectStep2
                      : l10n.wifiDirectStep2Named(network.ssid),
                  detail: network?.password == null
                      ? null
                      : l10n.wifiDirectPassword(network!.password!),
                ),
                const SizedBox(height: AppSpacing.xl),
                _Numbered(3, l10n.wifiDirectStep3),
              ],
            ),
          ),
          const StepMessages(),
          const SizedBox(height: AppSpacing.lg),
          AppSubmitButton(
            label: l10n.wifiDirectFind,
            onPressed: context.read<AddPrinterCubit>().findOnThisNetwork,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppNotice(status: AppStatus.info, message: l10n.wifiDirectNote),
        ],
      ),
    );
  }
}

class _Numbered extends StatelessWidget {
  const new(this.number, this.text, {this.detail});

  final int number;
  final String text;
  final String? detail;

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
              Text(text, style: textTheme.bodyLarge),
              if (detail != null) ...[
                const SizedBox(height: AppSpacing.xs),
                SelectableText(detail!, style: textTheme.titleMedium),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The printers near the phone, by Bluetooth signal. Picking one finds it
/// on the network.
class BluetoothStep extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => BluetoothSightingsCubit(
        scanner: context.read<PrinterFinders>().bluetooth,
      ),
      child: const _BluetoothList(),
    );
  }
}

class _BluetoothList extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final sightings = context.watch<BluetoothSightingsCubit>().state;

    return ListView(
      padding: _stepPadding,
      children: [
        Text(
          l10n.bluetoothBody,
          style: textTheme.bodyLarge?.copyWith(color: context.colors.textMuted),
        ),
        const StepMessages(),
        const SizedBox(height: AppSpacing.lg),
        if (sightings.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.bluetoothLooking, style: textTheme.titleSmall),
              ],
            ),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                for (final sighting in sightings)
                  ListTile(
                    leading: const Icon(Icons.bluetooth),
                    title: Text(sighting.name),
                    subtitle: Text(switch (sighting.nearness) {
                      Nearness.besideYou => l10n.bluetoothBeside,
                      Nearness.inTheRoom => l10n.bluetoothRoom,
                      Nearness.furtherAway => l10n.bluetoothFar,
                    }),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: context.colors.textMuted,
                    ),
                    onTap: () => context.read<AddPrinterCubit>().pickSighting(
                      sighting,
                      context.read<NearbyPrintersCubit>().state,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
