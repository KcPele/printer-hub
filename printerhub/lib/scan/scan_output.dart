import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printerhub/scan/signature.dart';
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

/// The phone's own document camera: it finds a page's edges, straightens
/// it, and hands back a picture of each page.
abstract interface class PageCamera {
  /// False on a phone that has none.
  bool get available;

  /// Opens the camera, and returns the pages taken as JPEG files, in
  /// order. Empty when the person took none. Throws when the camera could
  /// not be used.
  Future<List<File>> capture();
}

/// How the pages of a scan are made to look before they are kept.
enum ScanLook {
  /// As they arrived.
  original,

  /// Grey, with the paper lighter and the ink darker: for text.
  document,

  /// Brighter and stronger: for pen on a whiteboard, or a projected slide.
  whiteboard,

  /// Pure black on pure white: the smallest file, for clean print.
  blackAndWhite,
}

/// What is done to a scan as it is saved: how its pages look, and what is
/// put on them. None of it touches the pages as they were scanned, so
/// each can be undone by saving again.
class ScanFinish extends Equatable {
  const new({
    this.look = ScanLook.original,
    this.stamp,
    this.watermark = '',
    this.signature,
  });

  final ScanLook look;

  /// Words set small in the corner of every page, such as the date and
  /// time. Null for none.
  final String? stamp;

  /// A word set large and pale across every page, such as COPY. Empty for
  /// none.
  final String watermark;

  /// The person's signature, set on one sheet. Null for none.
  final PlacedSignature? signature;

  ScanFinish copyWith({
    ScanLook? look,
    String? Function()? stamp,
    String? watermark,
    PlacedSignature? Function()? signature,
  }) {
    return ScanFinish(
      look: look ?? this.look,
      stamp: stamp == null ? this.stamp : stamp(),
      watermark: watermark ?? this.watermark,
      signature: signature == null ? this.signature : signature(),
    );
  }

  @override
  List<Object?> get props => [look, stamp, watermark, signature];
}

/// [picture] made to look as [look] asks, as a JPEG. Null when it cannot
/// be read as a picture, and then it is kept as it is.
Uint8List? pictureWithLook(Uint8List picture, ScanLook look) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(picture);
  } on Object {
    return null;
  }
  if (decoded == null) return null;
  final changed = switch (look) {
    ScanLook.original => decoded,
    ScanLook.document => img.adjustColor(
      img.grayscale(decoded),
      contrast: 1.35,
      brightness: 1.05,
    ),
    ScanLook.whiteboard => img.adjustColor(
      decoded,
      contrast: 1.6,
      brightness: 1.15,
      saturation: 1.3,
    ),
    ScanLook.blackAndWhite => img.luminanceThreshold(decoded, threshold: 0.6),
  };
  return img.encodeJpg(changed, quality: 85);
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
///
/// [finish] says how picture pages are made to look, and what is set on
/// each page of the PDF: a stamp in the corner and a watermark across it.
/// Pages a scanner delivered as PDFs are left as they are.
Future<List<File>> assembleScan({
  required List<ScannedPage> pages,
  required String name,
  required String format,
  required Directory directory,
  ScanPaper paper = ScanPaper.a4,
  bool card = false,
  ScanFinish finish = const ScanFinish(),
}) async {
  final base = '${directory.path}/${scanFileName(name)}';
  final pictures = pages.every((page) => page.mimeType != 'application/pdf');

  // Each picture page as it will be kept: as it is, or with its look.
  // The work is done away from the screen's thread.
  final looked = <ScannedPage, Uint8List>{};
  if (finish.look != ScanLook.original) {
    for (final page in pages) {
      if (page.mimeType == 'application/pdf') continue;
      final raw = await page.file.readAsBytes();
      final changed = await Isolate.run(
        () => pictureWithLook(raw, finish.look),
      );
      if (changed != null) looked[page] = changed;
    }
  }

  if (format == 'application/pdf' && pictures) {
    try {
      final document = pw.Document(title: name);
      final sheet = PdfPageFormat(
        paper.widthMm * PdfPageFormat.mm,
        paper.heightMm * PdfPageFormat.mm,
      );
      final pictures = [
        for (final page in pages)
          pw.MemoryImage(looked[page] ?? await page.file.readAsBytes()),
      ];
      final watermark = finish.watermark.trim();
      final stamp = finish.stamp;
      final signed = finish.signature;
      final signature = signed == null ? null : pw.MemoryImage(signed.png);
      var sheetNumber = 0;
      for (var first = 0; first < pictures.length; first += card ? 2 : 1) {
        final picture = pictures[first];
        final back = card ? pictures.elementAtOrNull(first + 1) : null;
        final signHere = signed != null && signed.page == sheetNumber++;
        document.addPage(
          pw.Page(
            pageFormat: sheet,
            build: (_) => pw.Stack(
              children: [
                pw.Positioned.fill(
                  child: card
                      ? pw.Column(
                          children: [
                            pw.Expanded(child: _cardSide(picture)),
                            // A front without its back keeps to the top
                            // half.
                            pw.Expanded(
                              child: back == null
                                  ? pw.SizedBox()
                                  : _cardSide(back),
                            ),
                          ],
                        )
                      : pw.Center(child: pw.Image(picture)),
                ),
                if (watermark.isNotEmpty)
                  pw.Positioned.fill(
                    child: pw.Padding(
                      padding: pw.EdgeInsets.all(sheet.width / 8),
                      child: pw.Opacity(
                        opacity: 0.18,
                        child: pw.Watermark.text(
                          watermark,
                          style: const pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (signHere)
                  pw.Positioned(
                    left: signed.x * sheet.width,
                    top: signed.y * sheet.height,
                    child: pw.SizedBox(
                      width: signed.width * sheet.width,
                      child: pw.Image(signature!),
                    ),
                  ),
                if (stamp != null)
                  pw.Positioned(
                    right: 18,
                    bottom: 14,
                    child: pw.Text(
                      stamp,
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ),
              ],
            ),
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
      await _kept(
        page,
        looked[page],
        '$base${pages.length == 1 ? '' : ' ${index + 1}'}',
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

/// One page kept as a file of its own at [base]: as it arrived, or as the
/// JPEG its look made of it.
Future<File> _kept(ScannedPage page, Uint8List? looked, String base) async {
  if (looked != null) {
    final file = File('$base.jpg');
    await file.writeAsBytes(looked, flush: true);
    return file;
  }
  return await page.file.copy(
    '$base.${switch (page.mimeType) {
      'application/pdf' => 'pdf',
      'image/png' => 'png',
      _ => 'jpg',
    }}',
  );
}
