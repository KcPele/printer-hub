import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/library/library.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/session/session.dart';
import 'package:printerhub/tools/cubit/code_sheet_cubit.dart';
import 'package:printerhub/tools/made_pages.dart';
import 'package:printerhub/tools/view/make_scaffold.dart';

/// Makes a sign to print with a QR code on it: a link, some words, or a
/// Wi-Fi network to join.
class CodeSheetPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final name = context.l10n.toolsCodeSheetName(
      MaterialLocalizations.of(context).formatMediumDate(DateTime.now()),
    );
    return BlocProvider(
      create: (context) => CodeSheetCubit(
        sharer: context.read<ScanSharer>(),
        keep: context.read<Library>().keeper(
          context.read<SessionCubit>().state.organization!.id,
        ),
        name: name,
      ),
      child: const CodeSheetView(),
    );
  }
}

class CodeSheetView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<CodeSheetCubit>();
    final state = context.watch<CodeSheetCubit>().state;
    final choices = state.choices;
    final enabled = !state.working;

    return MakeScaffold(
      title: l10n.toolsCodeSheet,
      explanation: l10n.toolsCodeSheetExplanation,
      state: state,
      onMake: cubit.ready(choices) ? cubit.make : null,
      onShare: cubit.share,
      children: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(l10n.toolsCodeSheetLink)),
            ButtonSegment(value: true, label: Text(l10n.toolsCodeSheetWifi)),
          ],
          selected: {choices.wifi},
          onSelectionChanged: enabled
              ? (chosen) => cubit.change(choices.copyWith(wifi: chosen.single))
              : null,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (choices.wifi) ...[
          TextFormField(
            key: const ValueKey('code-network'),
            initialValue: choices.network,
            enabled: enabled,
            maxLength: 32,
            decoration: InputDecoration(labelText: l10n.toolsCodeSheetNetwork),
            onChanged: (network) =>
                cubit.change(cubit.state.choices.copyWith(network: network)),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            key: const ValueKey('code-password'),
            initialValue: choices.password,
            enabled: enabled,
            maxLength: 63,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l10n.toolsCodeSheetPassword,
              helperText: l10n.toolsCodeSheetPasswordHelp,
              helperMaxLines: 3,
            ),
            onChanged: (password) =>
                cubit.change(cubit.state.choices.copyWith(password: password)),
          ),
        ] else
          TextFormField(
            key: const ValueKey('code-text'),
            initialValue: choices.text,
            enabled: enabled,
            maxLength: CodeSheetCubit.maxLength,
            minLines: 1,
            maxLines: 4,
            autocorrect: false,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(labelText: l10n.toolsCodeSheetText),
            onChanged: (text) =>
                cubit.change(cubit.state.choices.copyWith(text: text)),
          ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          initialValue: choices.title,
          enabled: enabled,
          maxLength: 60,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l10n.toolsHeading),
          onChanged: (title) =>
              cubit.change(cubit.state.choices.copyWith(title: title)),
        ),
        const SizedBox(height: AppSpacing.sm),
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
