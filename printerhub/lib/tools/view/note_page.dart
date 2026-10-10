import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/tools/cubit/note_cubit.dart';
import 'package:printerhub/tools/made_pages.dart';
import 'package:printerhub/tools/view/make_scaffold.dart';

/// Prints words typed or pasted in, with no file needed.
class NotePage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final name = context.l10n.toolsNoteName(
      MaterialLocalizations.of(context).formatMediumDate(DateTime.now()),
    );
    return BlocProvider(
      create: (context) =>
          NoteCubit(sharer: context.read<ScanSharer>(), name: name),
      child: const NoteView(),
    );
  }
}

class NoteView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<NoteCubit>();
    final state = context.watch<NoteCubit>().state;
    final choices = state.choices;
    final enabled = !state.working;

    return MakeScaffold(
      title: l10n.toolsNote,
      explanation: l10n.toolsNoteExplanation,
      state: state,
      onMake: cubit.ready(choices) ? cubit.make : null,
      onShare: cubit.share,
      children: [
        TextFormField(
          initialValue: choices.title,
          enabled: enabled,
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l10n.toolsHeading),
          onChanged: (title) =>
              cubit.change(cubit.state.choices.copyWith(title: title)),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          key: const ValueKey('note-text'),
          initialValue: choices.text,
          enabled: enabled,
          minLines: 6,
          maxLines: 14,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l10n.toolsNoteText,
            alignLabelWithHint: true,
          ),
          onChanged: (text) =>
              cubit.change(cubit.state.choices.copyWith(text: text)),
        ),
        const SizedBox(height: AppSpacing.lg),
        PaperField(
          paper: choices.paper,
          papers: sheetPapers,
          onChanged: enabled
              ? (paper) =>
                    cubit.change(cubit.state.choices.copyWith(paper: paper))
              : null,
        ),
      ],
    );
  }
}
