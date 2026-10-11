import 'dart:async';
import 'dart:io';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/documents/cubit/document_view_cubit.dart';
import 'package:printerhub/documents/document_actions.dart';
import 'package:printerhub/documents/open_document.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/library/library.dart';
import 'package:printerhub/pictures/pictures.dart';
import 'package:printerhub/print/documents.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/session/session.dart';

/// A document, open: its pages one under another, edge to edge, and
/// below them what can be done with it. A page that is touched opens
/// full screen; a picture can be cropped, highlighted, and turned there,
/// and what is saved is kept as a new document. Printing and sharing
/// are a tap away; everything else the app can do with it is under
/// "More".
///
/// It is the one screen a document is opened in, wherever it came from.
class DocumentViewPage extends StatelessWidget {
  const new({required this.document, super.key});

  final OpenDocument document;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // Another document is another screen.
      key: ValueKey(document),
      create: (context) {
        final organization = context.read<SessionCubit>().state.organization;
        final cubit = DocumentViewCubit(
          renderer: context.read<PrintDocuments>().renderer,
          sharer: context.read<ScanSharer>(),
          document: document,
          keep: organization == null
              ? null
              : context.read<Library>().keeper(organization.id),
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const DocumentViewView(),
    );
  }
}

class DocumentViewView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<DocumentViewCubit>();
    final state = context.watch<DocumentViewCubit>().state;
    final document = state.document;

    /// Keeps a picture that was changed full screen, and says so.
    Future<void> keep(File changed) async {
      final messenger = ScaffoldMessenger.of(context);
      final name = document.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
      final kept = await cubit.keepChanged(
        changed,
        name: l10n.documentEditedName(name),
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            kept ? l10n.documentEditedSaved : l10n.documentEditedFailed,
          ),
        ),
      );
    }

    Widget page(int index) => OpenablePicture(
      picture: state.pages[index],
      onChanged: cubit.editable ? keep : null,
      child: Image.file(
        state.pages[index],
        key: ValueKey(state.pages[index].path),
        gaplessPlayback: true,
        semanticLabel: l10n.scanPageNumber(index + 1),
        errorBuilder: (_, _, _) => const Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Icon(Icons.image_outlined),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(document.name, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (state.status) {
                DocumentViewStatus.failed => EmptyState(
                  illustration: AppIllustrations.private,
                  title: l10n.documentViewFailedTitle,
                  message: l10n.documentViewFailedBody,
                ),
                _ when state.pages.isEmpty => const Center(
                  child: CircularProgressIndicator(),
                ),
                // One page is shown whole, as a photo is.
                _ when state.pages.length == 1 => Center(child: page(0)),
                _ => ListView.separated(
                  itemCount: state.pages.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, index) => page(index),
                ),
              },
            ),
            _Actions(document: document, onShare: cubit.share),
          ],
        ),
      ),
    );
  }
}

/// What can be done with the open document, along the foot of the screen:
/// the two things done most, and a way to the rest.
class _Actions extends StatelessWidget {
  const new({required this.document, required this.onShare});

  final OpenDocument document;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final prints = canPrintDocument(context, document);
    final tools = documentTools(context, document);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.outline)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: prints
                  ? FilledButton.icon(
                      onPressed: () => printDocument(context, document),
                      icon: const Icon(Icons.print_outlined),
                      label: Text(l10n.documentPrint),
                    )
                  : FilledButton.icon(
                      onPressed: onShare,
                      icon: const Icon(Icons.ios_share),
                      label: Text(l10n.documentSend),
                    ),
            ),
            if (prints) ...[
              const SizedBox(width: AppSpacing.sm),
              IconButton.outlined(
                tooltip: l10n.documentSend,
                onPressed: onShare,
                icon: const Icon(Icons.ios_share),
              ),
            ],
            if (tools.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  isScrollControlled: true,
                  builder: (_) => _Tools(tools: tools),
                ),
                icon: const Icon(Icons.apps_outlined),
                label: Text(l10n.documentMore),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The tools that work on the open document, to choose one from.
class _Tools extends StatelessWidget {
  const new({required this.tools});

  final List<DocumentAction> tools;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.sm,
            ),
            child: Text(
              context.l10n.documentMoreTitle,
              style: context.textTheme.titleLarge,
            ),
          ),
          for (final tool in tools)
            ListTile(
              leading: Icon(tool.icon, color: context.colors.emphasis),
              title: Text(tool.title),
              subtitle: Text(tool.body),
              onTap: () {
                // The sheet goes, and the tool opens over the document.
                Navigator.of(context).pop();
                tool.onTap();
              },
            ),
        ],
      ),
    );
  }
}
