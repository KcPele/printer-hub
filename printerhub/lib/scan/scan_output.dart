import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printers_repository/printers_repository.dart';

/// Hands finished scans to the phone's share sheet, where they can be
/// saved, sent, or opened in another app.
abstract interface class ScanSharer {
  Future<void> share(List<File> files, {required String name});
}

/// A paper size a scan can be made at.
class ScanPaper {
  const new(this.name, this.widthMm, this.heightMm);

  /// The PWG name, such as `iso_a4_210x297mm`.
  final String name;
  final double widthMm;
  final double heightMm;

  static const ScanPaper a4 = ScanPaper('iso_a4_210x297mm', 210, 297);

  /// The sizes offered, the usual one first.
  static const List<ScanPaper> all = [
    a4,
    ScanPaper('na_letter_8.5x11in', 215.9, 279.4),
    ScanPaper('iso_a5_148x210mm', 148, 210),
    ScanPaper('na_legal_8.5x14in', 215.9, 355.6),
  ];

  /// The size called [name], or A4.
  static ScanPaper named(String? name) {
    return all.firstWhere((paper) => paper.name == name, orElse: () => a4);
  }

  /// True when a scanner that takes [maxWidthMm] by [maxHeightMm] can scan
  /// it. A scanner that has not said takes anything.
  bool fits(num? maxWidthMm, num? maxHeightMm) {
    // Scanners round their own size down by a fraction of a millimetre.
    const slack = 2;
    return (maxWidthMm == null ||
            maxWidthMm <= 0 ||
            widthMm <= maxWidthMm + slack) &&
        (maxHeightMm == null ||
            maxHeightMm <= 0 ||
            heightMm <= maxHeightMm + slack);
  }
}

/// A name that is safe as a file name on any phone.
String scanFileName(String name) {
  final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '-').trim();
  return safe.isEmpty ? 'Scan' : safe;
}

/// Puts scanned [pages] together as what the person asked to keep, in
/// [directory], and returns the files.
///
/// Pictures become one PDF, a page each, when [format] is PDF. Otherwise,
/// and when the scanner delivered PDFs itself or pictures no PDF can be
/// made of, each page is a file of its own: `name.jpg`, or `name 1.jpg`
/// and `name 2.jpg`.
Future<List<File>> assembleScan({
  required List<ScannedPage> pages,
  required String name,
  required String format,
  required Directory directory,
  ScanPaper paper = ScanPaper.a4,
}) async {
  final base = '${directory.path}/${scanFileName(name)}';
  final pictures = pages.every((page) => page.mimeType != 'application/pdf');

  if (format == 'application/pdf' && pictures) {
    try {
      final document = pw.Document(title: name);
      for (final page in pages) {
        final picture = pw.MemoryImage(await page.file.readAsBytes());
        document.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(
              paper.widthMm * PdfPageFormat.mm,
              paper.heightMm * PdfPageFormat.mm,
            ),
            build: (_) => pw.Center(child: pw.Image(picture)),
          ),
        );
      }
      final file = File('$base.pdf');
      await file.writeAsBytes(await document.save(), flush: true);
      return [file];
    } on PdfException {
      // A picture the PDF writer cannot read. The scan is worth more than
      // its form: the pages are kept as the pictures they arrived as.
    }
  }

  return [
    for (final (index, page) in pages.indexed)
      await page.file.copy(
        '$base${pages.length == 1 ? '' : ' ${index + 1}'}'
        '.${page.mimeType == 'application/pdf' ? 'pdf' : 'jpg'}',
      ),
  ];
}
