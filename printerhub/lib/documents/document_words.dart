import 'package:documents_repository/documents_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/documents/cubit/documents_cubit.dart';
import 'package:printerhub/documents/document_sources.dart';
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

  static IconData icon(StoredDocument document) => iconOf(document.mimeType);

  /// The sign for a kind of file.
  static IconData iconOf(String mimeType) {
    return mimeType == 'application/pdf'
        ? Icons.picture_as_pdf_outlined
        : mimeType.startsWith('image/')
        ? Icons.image_outlined
        : Icons.description_outlined;
  }

  /// What made a document, from its source as `DocumentSources` names it.
  static String source(AppLocalizations l10n, String source) {
    return switch (source) {
      DocumentSources.printerScan => l10n.documentSourcePrinterScan,
      DocumentSources.cameraScan => l10n.documentSourceCameraScan,
      DocumentSources.joinedFiles => l10n.documentSourceJoinedFiles,
      DocumentSources.pdfPictures => l10n.toolsPictures,
      DocumentSources.longPicture => l10n.toolsLongPicture,
      DocumentSources.photoSheet => l10n.documentSourcePhotoSheet,
      DocumentSources.pagesPerSheet => l10n.toolsPerSheet,
      DocumentSources.codeSheet => l10n.documentSourceCodeSheet,
      DocumentSources.note => l10n.documentSourceNote,
      DocumentSources.printable => l10n.documentSourcePrintable,
      DocumentSources.editedPicture => l10n.documentSourceEdited,
      DocumentSources.signedPdf => l10n.toolsSign,
      DocumentSources.idPhoto => l10n.toolsIdPhoto,
      DocumentSources.bookPages => l10n.toolsBook,
      DocumentSources.lockedPdf => l10n.toolsLock,
      DocumentSources.searchablePdf => l10n.toolsSearchable,
      _ => l10n.documentSourceOther,
    };
  }

  /// How far back a list goes.
  static String age(AppLocalizations l10n, DocumentsAge age) {
    return switch (age) {
      DocumentsAge.any => l10n.documentsFilterAnyTime,
      DocumentsAge.today => l10n.documentsFilterToday,
      DocumentsAge.week => l10n.documentsFilterWeek,
      DocumentsAge.month => l10n.documentsFilterMonth,
    };
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
