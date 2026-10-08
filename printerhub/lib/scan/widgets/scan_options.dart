import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/print/print_words.dart';
import 'package:printerhub/scan/cubit/scan_cubit.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/scan/scan_words.dart';
import 'package:printers_repository/printers_repository.dart';

/// The choices for one scan. Only what the scanner offers is shown: one
/// without a feeder has nothing to choose a source from.
class ScanOptions extends StatelessWidget {
  const new({required this.printer, super.key});

  final PrinterRead printer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ScanCubit>();
    final choices = context.select<ScanCubit, ScanChoices>(
      (cubit) => cubit.state.choices,
    );
    final card = context.select<ScanCubit, bool>((cubit) => cubit.state.card);
    final offers = printer.capabilities?.scan;
    final sources = [
      for (final source in offers?.sources ?? const <Never>[]) ?source.json,
    ];
    final colors = [
      for (final mode in offers?.colorModes ?? const <Never>[]) ?mode.json,
    ];
    final resolutions = offers?.resolutionsDpi ?? const <int>[];
    final papers = [
      for (final paper in ScanPaper.all)
        if (paper.fits(offers?.maxWidthMm, offers?.maxHeightMm)) paper,
    ];
    const gap = SizedBox(height: AppSpacing.lg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ScanCubit.takesCards(printer))
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.scanCard),
            subtitle: Text(l10n.scanCardBody),
            value: card,
            onChanged: (on) => cubit.asCard(card: on),
          ),
        // A card is laid on the glass, and its two sides make one PDF.
        if (sources.length > 1 && !card) ...[
          Text(l10n.scanSource, style: context.textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String>(
            segments: [
              for (final source in sources)
                ButtonSegment(
                  value: source,
                  label: Text(ScanWords.source(l10n, source)),
                ),
            ],
            selected: {choices.source},
            onSelectionChanged: (chosen) =>
                cubit.change(choices.copyWith(source: chosen.single)),
          ),
        ],
        if (colors.contains('color') && colors.length > 1)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.scanColor),
            subtitle: Text(l10n.scanColorBody),
            value: choices.color == 'color',
            onChanged: (on) => cubit.change(
              choices.copyWith(color: on ? 'color' : 'grayscale'),
            ),
          ),
        if (!card && choices.fromFeeder && (offers?.adfDuplex ?? false))
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.scanDuplex),
            subtitle: Text(l10n.scanDuplexBody),
            value: choices.duplex,
            onChanged: (on) => cubit.change(choices.copyWith(duplex: on)),
          ),
        if (resolutions.length > 1) ...[
          gap,
          _Choice<int>(
            label: l10n.scanResolution,
            value: choices.resolutionDpi,
            options: {
              for (final dpi in resolutions)
                dpi: ScanWords.resolution(l10n, dpi),
            },
            onChanged: (dpi) =>
                cubit.change(choices.copyWith(resolutionDpi: dpi)),
          ),
        ],
        if (papers.length > 1) ...[
          gap,
          _Choice<String>(
            label: l10n.scanPaper,
            value: ScanPaper.named(choices.mediaSize).name,
            options: {
              for (final paper in papers)
                paper.name: PrintWords.paper(paper.name),
            },
            onChanged: (paper) =>
                cubit.change(choices.copyWith(mediaSize: () => paper)),
          ),
        ],
        if (!card) ...[
          gap,
          _Choice<String>(
            label: l10n.scanFormat,
            value: choices.format,
            options: {
              'application/pdf': l10n.scanFormatPdf,
              'image/jpeg': l10n.scanFormatPictures,
            },
            onChanged: (format) =>
                cubit.change(choices.copyWith(format: format)),
          ),
        ],
      ],
    );
  }
}

/// One choice among a few, with its label.
class _Choice<T extends Object> extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final String label;
  final T value;

  /// What can be chosen, and what each is called.
  final Map<T, String> options;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      // The field keeps what it began with; a choice the scanner made
      // otherwise needs a field of its own.
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
