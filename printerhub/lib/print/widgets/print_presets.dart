import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/errors/error_messages.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/print/cubit/presets_cubit.dart';
import 'package:printerhub/print/cubit/print_cubit.dart';
import 'package:printerhub/session/session.dart';

/// The saved ways of printing on this printer: tap one to use it, save the
/// choices made as another, or change the ones there are.
class PrintPresets extends StatelessWidget {
  const new({super.key});

  Future<void> _use(BuildContext context, Preset preset) async {
    final messenger = ScaffoldMessenger.of(context);
    final gone = context.l10n.presetGone;
    final print = context.read<PrintCubit>();
    final fresh = await context.read<PresetsCubit>().fresh(preset);
    final saved = fresh?.print;
    if (saved == null) {
      messenger.showSnackBar(SnackBar(content: Text(gone)));
    } else {
      print.use(saved);
    }
  }

  Future<void> _save(BuildContext context, {required bool canShare}) async {
    final presets = context.read<PresetsCubit>();
    final choices = context.read<PrintCubit>().state.choices;
    final named = await showDialog<PresetNamed>(
      context: context,
      builder: (_) => PresetNameDialog(
        title: context.l10n.presetSave,
        withStandard: true,
        canShare: canShare,
      ),
    );
    if (named == null) return;
    await presets.save(
      name: named.name,
      choices: choices,
      isDefault: named.standard,
      shared: named.shared,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<PresetsCubit>().state;
    final canManage = context.select<SessionCubit, bool>(
      (cubit) => cubit.state.organization?.canManage ?? false,
    );
    final error = state.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.presets.isNotEmpty) ...[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final preset in state.presets)
                ActionChip(
                  avatar: preset.isDefault
                      ? const Icon(Icons.star_rounded, size: 18)
                      : null,
                  label: Text(preset.name),
                  onPressed: () => _use(context, preset),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        if (error != null) ...[
          AppNotice(message: errorMessage(l10n, error)),
          const SizedBox(height: AppSpacing.xs),
        ],
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            TextButton.icon(
              onPressed: state.busy
                  ? null
                  : () => _save(context, canShare: canManage),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Text(l10n.presetSave),
            ),
            if (state.presets.isNotEmpty)
              TextButton(
                onPressed: () =>
                    showPresetsSheet(context, canManage: canManage),
                child: Text(l10n.presetManage),
              ),
          ],
        ),
      ],
    );
  }
}

/// What someone answered when asked to name saved settings.
typedef PresetNamed = ({String name, bool standard, bool shared});

/// Asks for the name of saved settings and, for new ones, whether prints
/// start with them and whether the workspace shares them.
class PresetNameDialog extends StatefulWidget {
  const new({
    required this.title,
    this.initialName = '',
    this.withStandard = false,
    this.canShare = false,
    super.key,
  });

  final String title;
  final String initialName;
  final bool withStandard;
  final bool canShare;

  @override
  State<PresetNameDialog> createState() => _PresetNameDialogState();
}

class _PresetNameDialogState extends State<PresetNameDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  bool _standard = false;
  bool _shared = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 100,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.presetNameLabel),
              onChanged: (_) => setState(() {}),
            ),
            if (widget.withStandard)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.presetStandard),
                value: _standard,
                onChanged: (on) => setState(() => _standard = on),
              ),
            if (widget.canShare)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.presetShare),
                value: _shared,
                onChanged: (on) => setState(() => _shared = on),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.presetCancel),
        ),
        TextButton(
          onPressed: _name.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop((
                  name: _name.text.trim(),
                  standard: _standard,
                  shared: _shared,
                )),
          child: Text(l10n.presetSaveConfirm),
        ),
      ],
    );
  }
}

enum _PresetAction { rename, standard, replace, delete }

/// Shows the saved settings with what can be done to each. Someone who is
/// not an admin changes only their own.
Future<void> showPresetsSheet(BuildContext context, {required bool canManage}) {
  final presets = context.read<PresetsCubit>();
  final print = context.read<PrintCubit>();

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: presets),
        BlocProvider.value(value: print),
      ],
      child: _PresetsSheet(canManage: canManage),
    ),
  );
}

class _PresetsSheet extends StatelessWidget {
  const new({required this.canManage});

  final bool canManage;

  Future<void> _do(
    BuildContext context,
    _PresetAction action,
    Preset preset,
  ) async {
    final presets = context.read<PresetsCubit>();
    switch (action) {
      case _PresetAction.rename:
        final named = await showDialog<PresetNamed>(
          context: context,
          builder: (_) => PresetNameDialog(
            title: context.l10n.presetRename,
            initialName: preset.name,
          ),
        );
        if (named != null) await presets.rename(preset, named.name);
      case _PresetAction.standard:
        await presets.setStandard(preset, standard: !preset.isDefault);
      case _PresetAction.replace:
        await presets.replace(preset, context.read<PrintCubit>().state.choices);
      case _PresetAction.delete:
        await presets.remove(preset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<PresetsCubit>().state;
    final error = state.error;

    return SafeArea(
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
            Text(l10n.presetsTitle, style: context.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            if (error != null) AppNotice(message: errorMessage(l10n, error)),
            for (final preset in state.presets)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(preset.name),
                subtitle: switch ((preset.shared, preset.isDefault)) {
                  (true, true) => Text(
                    '${l10n.presetShared}\n${l10n.presetStartsWith}',
                  ),
                  (true, false) => Text(l10n.presetShared),
                  (false, true) => Text(l10n.presetStartsWith),
                  (false, false) => null,
                },
                trailing: canManage || !preset.shared
                    ? PopupMenuButton<_PresetAction>(
                        enabled: !state.busy,
                        onSelected: (action) => _do(context, action, preset),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: _PresetAction.rename,
                            child: Text(l10n.presetRename),
                          ),
                          PopupMenuItem(
                            value: _PresetAction.standard,
                            child: Text(
                              preset.isDefault
                                  ? l10n.presetStopStandard
                                  : l10n.presetMakeStandard,
                            ),
                          ),
                          PopupMenuItem(
                            value: _PresetAction.replace,
                            child: Text(l10n.presetReplace),
                          ),
                          PopupMenuItem(
                            value: _PresetAction.delete,
                            child: Text(l10n.presetDelete),
                          ),
                        ],
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
