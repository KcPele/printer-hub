import 'dart:io';
import 'dart:math';

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
int passportPhotosOn(ScanPaper paper) =>
    photosFitOn(paper, widthMm: passportWidthMm, heightMm: passportHeightMm);

/// How many photos [widthMm] by [heightMm] one sheet of [paper] holds,
/// with a margin round the sheet and a gap between them to cut along.
int photosFitOn(
  ScanPaper paper, {
  required double widthMm,
  required double heightMm,
}) {
  final columns =
      ((paper.widthMm - 2 * _marginMm + _gapMm) / (widthMm + _gapMm)).floor();
  final rows = ((paper.heightMm - 2 * _marginMm + _gapMm) / (heightMm + _gapMm))
      .floor();
  return max(0, columns) * max(0, rows);
}

/// A sheet of [paper] filled with copies of [picture], each [widthMm] by
/// [heightMm] at full size, cut to fill and outlined faintly to cut
/// along.
pw.Page copiesSheet({
  required pw.ImageProvider picture,
  required ScanPaper paper,
  required double widthMm,
  required double heightMm,
}) {
  final count = photosFitOn(paper, widthMm: widthMm, heightMm: heightMm);
  return pw.Page(
    pageFormat: PdfPageFormat(
      paper.widthMm * PdfPageFormat.mm,
      paper.heightMm * PdfPageFormat.mm,
      marginAll: _marginMm * PdfPageFormat.mm,
    ),
    build: (_) => pw.Wrap(
      spacing: _gapMm * PdfPageFormat.mm,
      runSpacing: _gapMm * PdfPageFormat.mm,
      children: [
        for (var i = 0; i < count; i++)
          pw.Container(
            width: widthMm * PdfPageFormat.mm,
            height: heightMm * PdfPageFormat.mm,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.3),
            ),
            child: pw.ClipRect(child: pw.Image(picture, fit: pw.BoxFit.cover)),
          ),
      ],
    ),
  );
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
    // Each picture fills a sheet of its own with copies of itself.
    for (final picture in pictures) {
      document.addPage(
        copiesSheet(
          picture: picture,
          paper: paper,
          widthMm: passportWidthMm,
          heightMm: passportHeightMm,
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
