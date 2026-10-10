import 'package:app_ui/app_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/printers/finders.dart';
import 'package:printerhub/tools/code.dart';
import 'package:printerhub/tools/cubit/code_cubit.dart';
import 'package:printerhub/tools/tool_words.dart';

/// Reads a QR code or barcode with the camera: opens its link, or shows
/// what it says to copy.
class ScanCodePage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CodeCubit(links: context.read<LinkOpener>()),
      child: const ScanCodeView(),
    );
  }
}

class ScanCodeView extends StatelessWidget {
  const new({super.key});

  Future<void> _copy(BuildContext context, String text) async {
    final messenger = ScaffoldMessenger.of(context);
    final copied = context.l10n.toolsCodeCopied;
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(SnackBar(content: Text(copied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = context.textTheme;
    final cubit = context.read<CodeCubit>();
    final state = context.watch<CodeCubit>().state;
    final code = state.code;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.toolsCode)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: code == null
                ? [
                    Text(
                      l10n.toolsCodeLead,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ClipRRect(
                      borderRadius: context.shapes.cardRadius,
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: context.read<PrinterFinders>().qrScanner(
                          cubit.found,
                        ),
                      ),
                    ),
                  ]
                : [
                    AppCard(
                      tone: AppCardTone.muted,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ToolWords.codeKind(l10n, code.kind),
                            style: textTheme.labelLarge?.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          if (code.kind == CodeKind.wifi) ...[
                            SelectableText(
                              code.network,
                              style: textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            SelectableText(
                              code.password.isEmpty
                                  ? l10n.toolsCodeNoPassword
                                  : l10n.toolsCodePassword(code.password),
                              style: textTheme.bodyLarge,
                            ),
                          ] else
                            SelectableText(
                              code.text,
                              style: textTheme.bodyLarge,
                            ),
                        ],
                      ),
                    ),
                    if (state.unopened) ...[
                      const SizedBox(height: AppSpacing.sm),
                      AppNotice(message: l10n.toolsCodeUnopened),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    if (code.kind == CodeKind.link) ...[
                      AppSubmitButton(
                        label: l10n.toolsCodeOpen,
                        onPressed: cubit.open,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    // An open network has nothing to copy but its name.
                    OutlinedButton.icon(
                      onPressed: () => _copy(
                        context,
                        code.kind == CodeKind.wifi && code.password.isNotEmpty
                            ? code.password
                            : code.kind == CodeKind.wifi
                            ? code.network
                            : code.text,
                      ),
                      icon: const Icon(Icons.copy_outlined),
                      label: Text(
                        code.kind == CodeKind.wifi && code.password.isNotEmpty
                            ? l10n.toolsCodeCopyPassword
                            : l10n.toolsCodeCopy,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: cubit.again,
                      child: Text(l10n.toolsCodeAgain),
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}
