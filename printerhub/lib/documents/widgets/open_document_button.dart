import 'dart:io';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/documents/open_document.dart';
import 'package:printerhub/l10n/l10n.dart';

/// Opens a file the app has just made in the screen every document opens
/// in, where it can be read, printed, shared, and worked on with the
/// tools. Any screen that ends with a file can offer it.
class OpenDocumentButton extends StatelessWidget {
  const new({required this.file, super.key});

  final File file;

  /// What kind of file it is, from its name.
  static String mimeTypeOf(String name) {
    final dot = name.lastIndexOf('.');
    return switch (dot < 0 ? '' : name.substring(dot + 1).toLowerCase()) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'txt' => 'text/plain',
      _ => 'application/octet-stream',
    };
  }

  @override
  Widget build(BuildContext context) {
    final name = Uri.decodeComponent(file.uri.pathSegments.last);
    return OutlinedButton.icon(
      onPressed: () => context.go(
        AppRoutes.documentView,
        extra: OpenDocument(file: file, name: name, mimeType: mimeTypeOf(name)),
      ),
      icon: const Icon(Icons.open_in_new),
      label: Text(context.l10n.documentOpenIt),
    );
  }
}
