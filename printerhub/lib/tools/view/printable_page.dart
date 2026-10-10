import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/library/library.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/session/session.dart';
import 'package:printerhub/tools/cubit/printable_cubit.dart';
import 'package:printerhub/tools/made_pages.dart';
import 'package:printerhub/tools/tool_words.dart';
import 'package:printerhub/tools/view/make_scaffold.dart';

/// Prints a page that needs no file: lined, squared, or dotted paper, a
/// checklist, or a month's calendar.
class PrintablePage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final today = DateTime.now();
    return BlocProvider(
      create: (context) => PrintableCubit(
        sharer: context.read<ScanSharer>(),
        keep: context.read<Library>().keeper(
          context.read<SessionCubit>().state.organization!.id,
        ),
        name: l10n.toolsPrintableName(material.formatMediumDate(today)),
        today: today,
        calendar: (year, month) =>
            ToolWords.calendar(l10n, material, year, month),
      ),
      child: const PrintableView(),
    );
  }
}

class PrintableView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<PrintableCubit>();
    final state = context.watch<PrintableCubit>().state;
    final choices = state.choices;
    final enabled = !state.working;

    return MakeScaffold(
      title: l10n.toolsPrintable,
      explanation: l10n.toolsPrintableExplanation,
      state: state,
      onMake: cubit.make,
      onShare: cubit.share,
      children: [
        DropdownButtonFormField<Printable>(
          key: ValueKey(choices.kind),
          initialValue: choices.kind,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.toolsPrintableKind),
          items: [
            for (final kind in Printable.values)
              DropdownMenuItem(
                value: kind,
                child: Text(ToolWords.printable(l10n, kind)),
              ),
          ],
          onChanged: enabled
              ? (kind) => cubit.change(choices.copyWith(kind: kind))
              : null,
        ),
        if (choices.kind == Printable.calendar) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              IconButton(
                tooltip: l10n.toolsPrintableMonthBefore,
                onPressed: enabled
                    ? () => cubit.change(choices.later(-1))
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  MaterialLocalizations.of(context)
                      .formatMonthYear(DateTime(choices.year, choices.month)),
                  style: context.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                tooltip: l10n.toolsPrintableMonthAfter,
                onPressed: enabled
                    ? () => cubit.change(choices.later(1))
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        PaperField(
          paper: choices.paper,
          papers: sheetPapers,
          onChanged: enabled
              ? (paper) => cubit.change(choices.copyWith(paper: paper))
              : null,
        ),
      ],
    );
  }
}
