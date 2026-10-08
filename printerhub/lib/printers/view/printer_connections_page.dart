import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/auth/widgets/password_field.dart';
import 'package:printerhub/errors/error_messages.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/printers/cubit/connections_cubit.dart';
import 'package:printerhub/printers/cubit/printers_cubit.dart';
import 'package:printerhub/printers/printer_words.dart';
import 'package:printerhub/session/session.dart';
import 'package:printers_repository/printers_repository.dart';

/// The ways one printer is reached, in the order they are tried: which
/// work, which comes first, and adding, removing, and re-keying them.
class PrinterConnectionsPage extends StatelessWidget {
  const new({required this.printerId, super.key});

  final String printerId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = ConnectionsCubit(
          printersRepository: context.read<PrintersRepository>(),
          printersCubit: context.read<PrintersCubit>(),
          organizationId: context.read<SessionCubit>().state.organization!.id,
          printerId: printerId,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const PrinterConnectionsView(),
    );
  }
}

class PrinterConnectionsView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ConnectionsCubit>();
    final state = context.watch<ConnectionsCubit>().state;

    return BlocListener<ConnectionsCubit, ConnectionsState>(
      listenWhen: (previous, current) => current.notice != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(switch (state.notice!) {
              ConnectionsNotice.added => l10n.connectionsAdded,
              ConnectionsNotice.nothingNew => l10n.connectionsNothingNew,
              ConnectionsNotice.passwordChanged =>
                l10n.connectionsPasswordChanged,
            }),
          ),
        );
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.connectionsTitle)),
        body: SafeArea(
          child: switch (state.status) {
            ConnectionsStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            ConnectionsStatus.failed => EmptyState(
              illustration: AppIllustrations.printer,
              title: l10n.connectionsFailedTitle,
              message: errorMessage(l10n, state.error),
              action: FilledButton(
                onPressed: cubit.load,
                child: Text(l10n.loadingRetry),
              ),
            ),
            ConnectionsStatus.ready => _Connections(state: state),
          },
        ),
      ),
    );
  }
}

class _Connections extends StatelessWidget {
  const new({required this.state});

  final ConnectionsState state;

  /// Why the last change did not happen, when it did not.
  String? _problem(AppLocalizations l10n) => switch (state) {
    ConnectionsState(probeFailure: ProbeFailureKind.invalidAddress) =>
      l10n.addPrinterInvalid,
    ConnectionsState(probeFailure: ProbeFailureKind.unreachable) =>
      l10n.addPrinterUnreachable,
    ConnectionsState(probeFailure: ProbeFailureKind.notAPrinter) =>
      l10n.addPrinterNotAPrinter,
    ConnectionsState(probeFailure: ProbeFailureKind.needsPassword) =>
      l10n.connectionsNeedsPassword,
    ConnectionsState(probeFailure: ProbeFailureKind.wrongPassword) =>
      l10n.printerPasswordWrong,
    ConnectionsState(:final error?) => errorMessage(l10n, error),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final problem = _problem(l10n);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xxl,
      ),
      children: [
        Text(
          l10n.connectionsBody,
          style: textTheme.bodyLarge?.copyWith(color: context.colors.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (state.busy) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (problem != null) ...[
          AppNotice(message: problem),
          const SizedBox(height: AppSpacing.lg),
        ],
        for (final (index, connection) in state.connections.indexed) ...[
          _ConnectionCard(
            connection: connection,
            isFirst: index == 0,
            isOnly: state.connections.length == 1,
            enabled: !state.busy,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.connectionsAddTitle, style: textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.connectionsAddBody,
          style: textTheme.bodyMedium?.copyWith(
            color: context.colors.textMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _AddAddress(busy: state.busy),
      ],
    );
  }
}

enum _Action { preferFirst, changePassword, remove }

class _ConnectionCard extends StatelessWidget {
  const new({
    required this.connection,
    required this.isFirst,
    required this.isOnly,
    required this.enabled,
  });

  final ConnectionRead connection;
  final bool isFirst;
  final bool isOnly;
  final bool enabled;

  bool get _prints => connection.type != ConnectionType.escl;

  Future<void> _changePassword(BuildContext context) async {
    final cubit = context.read<ConnectionsCubit>();
    final entered = await showDialog<PrinterCredentials>(
      context: context,
      builder: (_) => const _PasswordDialog(),
    );
    if (entered == null) return;
    await cubit.setPassword(
      connection,
      userName: entered.userName,
      password: entered.password,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ConnectionsCubit>();
    final standing = PrinterWords.health(l10n, connection);
    final configuration = connection.configuration;
    final details = [
      (connection.type.json ?? '').toUpperCase(),
      if (configuration.port != null) '${configuration.port}',
      if (configuration.tls ?? false) l10n.connectionsSecure,
      if (isFirst) l10n.connectionsFirst,
    ].join(' · ');

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Icon(
              _prints ? Icons.print_outlined : Icons.document_scanner_outlined,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  PrinterWords.connection(l10n, connection),
                  style: context.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  details,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                StatusPill(status: standing.status, label: standing.label),
              ],
            ),
          ),
          PopupMenuButton<_Action>(
            enabled: enabled,
            onSelected: (action) => switch (action) {
              _Action.preferFirst => cubit.preferFirst(connection),
              _Action.changePassword => _changePassword(context),
              _Action.remove => cubit.remove(connection),
            },
            itemBuilder: (_) => [
              if (!isFirst)
                PopupMenuItem(
                  value: _Action.preferFirst,
                  child: Text(l10n.connectionsPreferFirst),
                ),
              if (_prints)
                PopupMenuItem(
                  value: _Action.changePassword,
                  child: Text(l10n.connectionsChangePassword),
                ),
              // A printer with no way in could not be used at all.
              if (!isOnly)
                PopupMenuItem(
                  value: _Action.remove,
                  child: Text(l10n.connectionsRemove),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddAddress extends StatefulWidget {
  const new({required this.busy});

  final bool busy;

  @override
  State<_AddAddress> createState() => _AddAddressState();
}

class _AddAddressState extends State<_AddAddress> {
  final _address = TextEditingController();

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    FocusScope.of(context).unfocus();
    await context.read<ConnectionsCubit>().addAddress(_address.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppCard(
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
          const SizedBox(height: AppSpacing.lg),
          AppSubmitButton(
            label: l10n.connectionsAddAction,
            loading: widget.busy,
            onPressed: _find,
          ),
        ],
      ),
    );
  }
}

/// Asks for the user name and password the printer wants. Pops with them,
/// or with nothing when it is cancelled.
class _PasswordDialog extends StatefulWidget {
  const new();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _userName = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _userName.dispose();
    _password.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.of(context).pop(
      PrinterCredentials(
        userName: _userName.text.trim(),
        password: _password.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.connectionsPasswordTitle),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              validator: (value) =>
                  (value ?? '').isEmpty ? l10n.printerPasswordNeeded : null,
              onSubmitted: _save,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.connectionsCancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(l10n.connectionsPasswordSave),
        ),
      ],
    );
  }
}
