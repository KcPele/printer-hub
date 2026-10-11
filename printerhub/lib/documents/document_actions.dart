import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/documents/open_document.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/printers/widgets/printer_choice_sheet.dart';
import 'package:printerhub/workspace/cubit/features_cubit.dart';

/// One thing that can be done with an open document.
class DocumentAction {
  const new({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
}

/// True when [document] is a kind the app prints and the workspace has a
/// printer that prints.
bool canPrintDocument(BuildContext context, OpenDocument document) {
  return (document.isPdf || document.isPicture) &&
      printersThatPrint(context).isNotEmpty;
}

/// Sends [document] to a printer the person picks.
Future<void> printDocument(BuildContext context, OpenDocument document) async {
  final router = GoRouter.of(context);
  final printer = await choosePrinter(context);
  if (printer == null) return;
  router.go(AppRoutes.printOn(printer.id), extra: document.picked);
}

/// Every tool that works on [document], in the order they are offered.
/// The tool opens with the document already in it: nothing is chosen
/// again.
///
/// This is the one place that says what can be done with an open
/// document. A tool that learns to take a file is added here, and every
/// screen that opens a document offers it.
List<DocumentAction> documentTools(
  BuildContext context,
  OpenDocument document,
) {
  final l10n = context.l10n;
  final reads = context.read<FeaturesCubit>().enabled('local_ocr');
  void open(String route) {
    unawaited(context.push(route, extra: document.picked));
  }

  return [
    if (document.isPdf || document.isPicture)
      DocumentAction(
        icon: Icons.auto_fix_high_outlined,
        title: l10n.documentToolEdit,
        body: l10n.documentToolEditBody,
        onTap: () => open(AppRoutes.documentEdit),
      ),
    if (reads && (document.isPdf || document.isPicture))
      DocumentAction(
        icon: Icons.text_snippet_outlined,
        title: l10n.toolsText,
        body: l10n.toolsTextBody,
        onTap: () => open(AppRoutes.documentText),
      ),
    if (document.isPdf) ...[
      DocumentAction(
        icon: Icons.image_outlined,
        title: l10n.toolsPictures,
        body: l10n.toolsPicturesBody,
        onTap: () => open(AppRoutes.documentPictures),
      ),
      DocumentAction(
        icon: Icons.view_day_outlined,
        title: l10n.toolsLongPicture,
        body: l10n.toolsLongPictureBody,
        onTap: () => open(AppRoutes.documentLongPicture),
      ),
      DocumentAction(
        icon: Icons.grid_view_outlined,
        title: l10n.toolsPerSheet,
        body: l10n.toolsPerSheetBody,
        onTap: () => open(AppRoutes.documentPerSheet),
      ),
    ],
  ];
}
