import 'package:api_client/api_client.dart' show DuplexMode;
import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/print/cubit/print_cubit.dart';
import 'package:printerhub/print/print_words.dart';
import 'package:printers_repository/printers_repository.dart';

/// The choices for one print. Only what the printer offers is shown: a
/// printer without colour has no colour switch.
class PrintOptions extends StatelessWidget {
  const new({required this.printer, required this.pageCount, super.key});

  final PrinterRead printer;
  final int pageCount;

  /// What a page range may look like: `1-3, 5`.
  static final RegExp _ranges = RegExp(r'^\d+(-\d+)?(\s*,\s*\d+(-\d+)?)*$');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<PrintCubit>();
    final choices = context.select<PrintCubit, PrintChoices>(
      (cubit) => cubit.state.choices,
    );
    final offers = printer.capabilities?.print;
    final sides = [
      for (final mode in offers?.duplexModes ?? const <DuplexMode>[])
        ?mode.json,
    ];
    final papers = offers?.mediaSizes ?? const <String>[];
    final trays = offers?.trays ?? const [];
    final qualities = offers?.qualityModes ?? const <String>[];
    const gap = SizedBox(height: AppSpacing.lg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(l10n.printCopies, style: context.textTheme.bodyLarge),
            ),
            IconButton(
              tooltip: '−',
              onPressed: choices.copies > 1
                  ? () => cubit.change(
                      choices.copyWith(copies: choices.copies - 1),
                    )
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: AppSpacing.xxl,
              child: Text(
                '${choices.copies}',
                style: context.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              tooltip: '+',
              onPressed: choices.copies < (offers?.maxCopies ?? 99)
                  ? () => cubit.change(
                      choices.copyWith(copies: choices.copies + 1),
                    )
                  : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        if (offers?.color ?? false)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.printColor),
            subtitle: Text(l10n.printColorBody),
            value: choices.color != 'monochrome',
            onChanged: (on) => cubit.change(
              choices.copyWith(color: on ? 'auto' : 'monochrome'),
            ),
          ),
        if (sides.length > 1) ...[
          gap,
          _Choice(
            label: l10n.printSides,
            value: choices.sides,
            options: {
              for (final mode in sides) mode: PrintWords.sides(l10n, mode),
            },
            onChanged: (mode) => cubit.change(choices.copyWith(sides: mode)),
          ),
        ],
        if (papers.isNotEmpty) ...[
          gap,
          _Choice(
            label: l10n.printPaper,
            value: choices.mediaSize,
            options: {
              null: l10n.printAutomatic,
              for (final paper in papers) paper: PrintWords.paper(paper),
            },
            onChanged: (paper) =>
                cubit.change(choices.copyWith(mediaSize: () => paper)),
          ),
        ],
        if (trays.isNotEmpty) ...[
          gap,
          _Choice(
            label: l10n.printTray,
            value: choices.tray,
            options: {
              null: l10n.printAutomatic,
              for (final tray in trays) tray.id: PrintWords.tray(l10n, tray.id),
            },
            onChanged: (tray) =>
                cubit.change(choices.copyWith(tray: () => tray)),
          ),
        ],
        if (qualities.length > 1) ...[
          gap,
          _Choice(
            label: l10n.printQuality,
            value: choices.quality,
            options: {
              null: l10n.printAutomatic,
              for (final quality in qualities)
                quality: PrintWords.quality(l10n, quality),
            },
            onChanged: (quality) =>
                cubit.change(choices.copyWith(quality: () => quality)),
          ),
        ],
        if (pageCount > 1) ...[
          gap,
          TextFormField(
            initialValue: choices.pageRanges,
            keyboardType: TextInputType.text,
            autocorrect: false,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              final text = (value ?? '').trim();
              return text.isEmpty || _ranges.hasMatch(text)
                  ? null
                  : l10n.printPagesInvalid;
            },
            onChanged: (value) {
              final text = value.trim();
              if (text.isNotEmpty && !_ranges.hasMatch(text)) return;
              cubit.change(
                choices.copyWith(
                  pageRanges: () =>
                      text.isEmpty ? null : text.replaceAll(' ', ''),
                ),
              );
            },
            decoration: InputDecoration(
              labelText: l10n.printPages,
              hintText: l10n.printPagesHint,
              prefixIcon: const Icon(Icons.format_list_numbered),
            ),
          ),
        ],
      ],
    );
  }
}

/// One choice among a few, with its label.
class _Choice extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;

  /// What can be chosen, and what each is called.
  final Map<String?, String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      // The field keeps what it began with, so saved settings taking the
      // place of the choices need a field of their own.
      key: ValueKey(value),
      initialValue: options.containsKey(value) ? value : options.keys.first,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final MapEntry(key: option, value: name) in options.entries)
          DropdownMenuItem(value: option, child: Text(name)),
      ],
      onChanged: onChanged,
    );
  }
}
