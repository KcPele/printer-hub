import 'dart:async';
import 'dart:io';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/documents/cubit/made_files_cubit.dart';
import 'package:printerhub/documents/open_document.dart';
import 'package:printerhub/documents/view/documents_page.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/print/documents.dart';

/// The files a screen has just made, each shown as it looks, with its
/// name. Touching one opens it in the screen every document opens in,
/// where it is read, printed, shared, and worked on with the tools: so
/// what was made can be looked at without leaving the screen that made
/// it.
///
/// Every screen that ends with files shows them with this, never as
/// names alone.
class MadeFiles extends StatelessWidget {
  const new({required this.files, super.key});

  final List<File> files;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // Other files are other pictures.
      key: ValueKey([for (final file in files) file.path].join('\n')),
      create: (context) {
        final cubit = MadeFilesCubit(
          renderer: context.read<PrintDocuments>().renderer,
          files: files,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: BlocBuilder<MadeFilesCubit, Map<String, String>>(
        builder: (context, pictures) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final file in files)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _MadeFile(file: file, picture: pictures[file.path]),
              ),
          ],
        ),
      ),
    );
  }
}

class _MadeFile extends StatelessWidget {
  const new({required this.file, required this.picture});

  final File file;
  final String? picture;

  @override
  Widget build(BuildContext context) {
    final name = Uri.decodeComponent(file.uri.pathSegments.last);
    final mimeType = mimeTypeOfName(name);

    return Semantics(
      button: true,
      label: context.l10n.madeFileOpen(name),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        // Pushed, so going back returns to the screen that made it.
        onTap: () => context.push(
          AppRoutes.documentView,
          extra: OpenDocument(file: file, name: name, mimeType: mimeType),
        ),
        child: Row(
          children: [
            DocumentLikeness(mimeType: mimeType, picture: picture),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Text(
                name,
                style: context.textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.chevron_right, color: context.colors.textMuted),
          ],
        ),
      ),
    );
  }
}
