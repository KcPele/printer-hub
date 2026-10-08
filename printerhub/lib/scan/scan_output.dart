import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printers_repository/printers_repository.dart';

/// Hands finished scans to the phone's share sheet, where they can be
/// saved, sent, or opened in another app.
abstract interface class ScanSharer {
  Future<void> share(List<File> files, {required String name});
}

/// Reads the words in scanned pages. It works on the phone: no page
/// leaves it to be read.
// One member, but a class so the app can be given a stand-in for it.
abstract interface class ScanTextReader {
  /// The words in [pictures], one page after another. Empty when there
  /// are none. Throws when this phone cannot read them.
  Future<String> read(List<File> pictures);
}

/// A paper size a scan can be made at.
class ScanPaper {
  const new(this.name, this.widthMm, this.heightMm);

  /// The PWG name, such as `iso_a4_210x297mm`.
  final String name;
  final double widthMm;
  final double heightMm;

  static const ScanPaper a4 = ScanPaper('iso_a4_210x297mm', 210, 297);

  /// The corner of the glass scanned for an ID card. The card is 85.6 mm
  /// by 54 mm; the rest is for a card not laid exactly in the corner.
  static const ScanPaper card = ScanPaper('iso_id-1_53.98x85.6mm', 92, 60);

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
///
/// With [card], the pages are the sides of ID cards, front then back.
/// They are laid two to a sheet of [paper], one above the other, each the
/// size it was scanned at, so a printed copy matches the card.
Future<List<File>> assembleScan({
  required List<ScannedPage> pages,
  required String name,
  required String format,
  required Directory directory,
  ScanPaper paper = ScanPaper.a4,
  bool card = false,
}) async {
  final base = '${directory.path}/${scanFileName(name)}';
  final pictures = pages.every((page) => page.mimeType != 'application/pdf');

  if (format == 'application/pdf' && pictures) {
    try {
      final document = pw.Document(title: name);
      final sheet = PdfPageFormat(
        paper.widthMm * PdfPageFormat.mm,
        paper.heightMm * PdfPageFormat.mm,
      );
      final pictures = [
        for (final page in pages) pw.MemoryImage(await page.file.readAsBytes()),
      ];
      for (var first = 0; first < pictures.length; first += card ? 2 : 1) {
        final picture = pictures[first];
        final back = card ? pictures.elementAtOrNull(first + 1) : null;
        document.addPage(
          pw.Page(
            pageFormat: sheet,
            build: (_) => card
                ? pw.Column(
                    children: [
                      pw.Expanded(child: _cardSide(picture)),
                      // A front without its back keeps to the top half.
                      pw.Expanded(
                        child: back == null ? pw.SizedBox() : _cardSide(back),
                      ),
                    ],
                  )
                : pw.Center(child: pw.Image(picture)),
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

/// One side of a card, in the middle of its half of the sheet, at the size
/// it was scanned.
pw.Widget _cardSide(pw.ImageProvider picture) {
  return pw.Center(
    child: pw.SizedBox(
      width: ScanPaper.card.widthMm * PdfPageFormat.mm,
      height: ScanPaper.card.heightMm * PdfPageFormat.mm,
      child: pw.Image(picture),
    ),
  );
}
