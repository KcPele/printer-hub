import 'dart:async';
import 'dart:io';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/documents/cubit/document_view_cubit.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/print/documents.dart';
import 'package:printerhub/scan/scan_output.dart';

/// A document, open to be read: its pages one under another, to pinch
/// larger. Sharing it is a button away.
class DocumentViewPage extends StatelessWidget {
  const new({
    required this.file,
    required this.name,
    required this.mimeType,
    super.key,
  });

  final File file;

  /// Its file name, shown as the title.
  final String name;
  final String mimeType;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = DocumentViewCubit(
          renderer: context.read<PrintDocuments>().renderer,
          sharer: context.read<ScanSharer>(),
          file: file,
          name: name,
          mimeType: mimeType,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: DocumentViewView(name: name),
    );
  }
}

class DocumentViewView extends StatelessWidget {
  const new({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<DocumentViewCubit>();
    final state = context.watch<DocumentViewCubit>().state;

    return Scaffold(
      appBar: AppBar(
        title: Text(name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: l10n.documentSend,
            onPressed: cubit.share,
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: SafeArea(
        child: switch (state.status) {
          DocumentViewStatus.failed => EmptyState(
            illustration: AppIllustrations.private,
            title: l10n.documentViewFailedTitle,
            message: l10n.documentViewFailedBody,
            action: FilledButton(
              onPressed: cubit.share,
              child: Text(l10n.documentSend),
            ),
          ),
          _ when state.pages.isEmpty => const Center(
            child: CircularProgressIndicator(),
          ),
          _ => InteractiveViewer(
            maxScale: 5,
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: state.pages.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) => DecoratedBox(
                // A page is white, whatever the theme: it is paper.
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: context.colors.outline),
                ),
                child: Image.memory(
                  state.pages[index],
                  gaplessPlayback: true,
                  semanticLabel: l10n.scanPageNumber(index + 1),
                ),
              ),
            ),
          ),
        },
      ),
    );
  }
}
