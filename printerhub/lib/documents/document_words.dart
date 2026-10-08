import 'package:documents_repository/documents_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';

/// The words the app uses for a document the workspace keeps: how big it
/// is, and what there is to know of it at a glance.
abstract final class DocumentWords {
  /// A size as people say it: `28 KB`, `1.4 MB`.
  static String size(AppLocalizations l10n, int bytes) {
    const kb = 1024;
    if (bytes < kb * kb) {
      final whole = (bytes / kb).ceil();
      return l10n.documentSizeKb('${whole < 1 ? 1 : whole}');
    }
    return l10n.documentSizeMb((bytes / (kb * kb)).toStringAsFixed(1));
  }

  static IconData icon(StoredDocument document) {
    return document.mimeType == 'application/pdf'
        ? Icons.picture_as_pdf_outlined
        : document.mimeType.startsWith('image/')
        ? Icons.image_outlined
        : Icons.description_outlined;
  }

  /// What is worth knowing of a document in one line: its pages, its
  /// size, and the day it was made.
  static String detail(BuildContext context, StoredDocument document) {
    final l10n = context.l10n;
    final pages = document.pageCount;
    return [
      if (pages != null && pages > 0) l10n.printPageCount(pages),
      size(l10n, document.sizeBytes),
      MaterialLocalizations.of(context)
          .formatMediumDate(document.createdAt.toLocal()),
    ].join(' · ');
  }
}
