import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printerhub/scan/scan_output.dart';

/// How photos are laid out on a sheet to print.
enum PhotoLayout {
  /// One photo, as large as the sheet takes.
  one(1),

  /// Two, one above the other.
  two(2),

  /// Four, two by two.
  four(4),

  /// As many passport photos, 35 mm by 45 mm, as the sheet holds, all of
  /// the same picture.
  passport(0);

  new(this.perSheet);

  /// How many different photos share a sheet. None for [passport], where
  /// the sheet is filled with one.
  final int perSheet;
}

/// The paper a sheet of photos is made for. The first is the usual one.
const List<ScanPaper> photoPapers = [
  ScanPaper.a4,
  ScanPaper('na_letter_8.5x11in', 215.9, 279.4),
  // The small glossy sheet most home printers take for photos.
  ScanPaper('na_index-4x6_4x6in', 101.6, 152.4),
];

/// A passport photo is this size nearly everywhere outside North America.
const double passportWidthMm = 35;
const double passportHeightMm = 45;

const double _marginMm = 6;
const double _gapMm = 4;

/// How many passport photos one sheet of [paper] holds.
int passportPhotosOn(ScanPaper paper) {
  final columns =
      ((paper.widthMm - 2 * _marginMm + _gapMm) / (passportWidthMm + _gapMm))
          .floor();
  final rows =
      ((paper.heightMm - 2 * _marginMm + _gapMm) / (passportHeightMm + _gapMm))
          .floor();
  return columns * rows;
}

/// Lays [photos] out on sheets of [paper] as [layout] says, and writes
/// the PDF to [directory]. Printed at full size, a passport photo comes
/// out 35 mm by 45 mm.
///
/// Throws a [PdfException] when a photo cannot be read as a picture.
Future<File> photoSheet({
  required List<File> photos,
  required PhotoLayout layout,
  required ScanPaper paper,
  required String name,
  required Directory directory,
}) async {
  final document = pw.Document(title: name);
  final sheet = PdfPageFormat(
    paper.widthMm * PdfPageFormat.mm,
    paper.heightMm * PdfPageFormat.mm,
    marginAll: _marginMm * PdfPageFormat.mm,
  );
  final pictures = [
    for (final photo in photos) pw.MemoryImage(await photo.readAsBytes()),
  ];
  const gap = _gapMm * PdfPageFormat.mm;

  if (layout == PhotoLayout.passport) {
    final count = passportPhotosOn(paper);
    // Each picture fills a sheet of its own with copies of itself.
    for (final picture in pictures) {
      document.addPage(
        pw.Page(
          pageFormat: sheet,
          build: (_) => pw.Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var i = 0; i < count; i++)
                pw.SizedBox(
                  width: passportWidthMm * PdfPageFormat.mm,
                  height: passportHeightMm * PdfPageFormat.mm,
                  // Cut to fill, as a passport photo is.
                  child: pw.ClipRect(
                    child: pw.Image(picture, fit: pw.BoxFit.cover),
                  ),
                ),
            ],
          ),
        ),
      );
    }
  } else {
    final columns = layout == PhotoLayout.four ? 2 : 1;
    for (var first = 0; first < pictures.length; first += layout.perSheet) {
      final onSheet = pictures.skip(first).take(layout.perSheet).toList();
      document.addPage(
        pw.Page(
          pageFormat: sheet,
          build: (_) => pw.Column(
            children: [
              for (var row = 0; row * columns < layout.perSheet; row++) ...[
                if (row > 0) pw.SizedBox(height: gap),
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      for (var column = 0; column < columns; column++) ...[
                        if (column > 0) pw.SizedBox(width: gap),
                        pw.Expanded(
                          child: switch (onSheet.elementAtOrNull(
                            row * columns + column,
                          )) {
                            final picture? => pw.Center(
                              child: pw.Image(picture),
                            ),
                            // The last sheet may have room to spare.
                            null => pw.SizedBox(),
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
  }

  final file = File('${directory.path}/${scanFileName(name)}.pdf');
  await file.writeAsBytes(await document.save(), flush: true);
  return file;
}
