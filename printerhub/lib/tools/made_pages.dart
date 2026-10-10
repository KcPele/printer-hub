import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printerhub/scan/scan_output.dart';

/// The pages the app makes itself, from nothing but what the person
/// typed or chose: a sign with a code on it, a note, a ruled page, a
/// calendar, and a document's pages set several to a sheet.
///
/// Each is a PDF at the paper's true size. `font` is a TrueType font for
/// the words; without one only plain Latin letters can be set.

const double _marginMm = 15;

/// The papers a made page can be set on.
const List<ScanPaper> sheetPapers = [
  ScanPaper.a4,
  ScanPaper('na_letter_8.5x11in', 215.9, 279.4),
];

PdfPageFormat _sheet(ScanPaper paper, {bool sideways = false}) {
  final width = paper.widthMm * PdfPageFormat.mm;
  final height = paper.heightMm * PdfPageFormat.mm;
  return PdfPageFormat(
    sideways ? height : width,
    sideways ? width : height,
    marginAll: _marginMm * PdfPageFormat.mm,
  );
}

pw.ThemeData? _theme(ByteData? font) {
  if (font == null) return null;
  final words = pw.Font.ttf(font);
  // One file serves for headings too: they are set larger, not heavier.
  return pw.ThemeData.withFont(base: words, bold: words);
}

Future<File> _written(
  pw.Document document,
  String name,
  Directory directory,
) async {
  final file = File('${directory.path}/${scanFileName(name)}.pdf');
  await file.writeAsBytes(await document.save(), flush: true);
  return file;
}

/// What a QR code says to join a Wi-Fi network called [network]. With no
/// [password] the network is an open one.
String wifiCode({required String network, String password = ''}) {
  String escaped(String text) =>
      text.replaceAllMapped(RegExp(r'[\\;,:"]'), (match) => '\\${match[0]}');
  return password.isEmpty
      ? 'WIFI:T:nopass;S:${escaped(network)};;'
      : 'WIFI:T:WPA;S:${escaped(network)};P:${escaped(password)};;';
}

/// A sign with a QR code saying [data] on it, large, with [title] above
/// and [caption] below.
Future<File> codeSheet({
  required String data,
  required ScanPaper paper,
  required String name,
  required Directory directory,
  String title = '',
  String caption = '',
  ByteData? font,
}) {
  final sheet = _sheet(paper);
  final document = pw.Document(title: name, theme: _theme(font))
    ..addPage(
      pw.Page(
        pageFormat: sheet,
        build: (_) => pw.Center(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              if (title.trim().isNotEmpty) ...[
                pw.Text(
                  title.trim(),
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                    fontSize: 30,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 24),
              ],
              pw.BarcodeWidget(
                data: data,
                barcode: pw.Barcode.qrCode(),
                width: sheet.availableWidth * 0.7,
                height: sheet.availableWidth * 0.7,
                drawText: false,
              ),
              if (caption.trim().isNotEmpty) ...[
                pw.SizedBox(height: 24),
                pw.Text(
                  caption.trim(),
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 16),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  return _written(document, name, directory);
}

/// [text] set as a document, under [title], on as many sheets as it
/// takes.
Future<File> noteSheet({
  required String text,
  required ScanPaper paper,
  required String name,
  required Directory directory,
  String title = '',
  ByteData? font,
}) {
  final document = pw.Document(title: name, theme: _theme(font))
    ..addPage(
      pw.MultiPage(
        pageFormat: _sheet(paper),
        build: (_) => [
          if (title.trim().isNotEmpty) ...[
            pw.Text(
              title.trim(),
              style: const pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
          ],
          // A paragraph each, so a long note breaks between them.
          for (final paragraph in text.trim().split('\n'))
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Text(
                paragraph,
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 3),
              ),
            ),
        ],
      ),
    );
  return _written(document, name, directory);
}

/// The ruled pages the app can print.
enum Printable {
  /// Lines to write on.
  lined,

  /// Squares, 5 mm.
  grid,

  /// Dots, 5 mm apart.
  dots,

  /// Boxes to tick, each with a line beside it.
  checklist,

  /// One month, a box a day.
  calendar,
}

/// What a calendar needs to be told, since the app's words are not known
/// here: the month, what to call it, and the days of the week in the
/// order they are shown.
class CalendarMonth {
  const new({
    required this.year,
    required this.month,
    required this.title,
    required this.weekdays,
    this.firstWeekday = DateTime.monday,
  });

  final int year;
  final int month;

  /// Such as "October 2026".
  final String title;

  /// Seven names, beginning with [firstWeekday].
  final List<String> weekdays;

  /// The day a week begins on, as `DateTime.monday` to `DateTime.sunday`.
  final int firstWeekday;
}

const double _ruleMm = 8;
const double _squareMm = 5;
const PdfColor _rule = PdfColor.fromInt(0xFF9AA0A6);

/// One sheet of [kind]. A calendar needs its [month].
Future<File> printableSheet({
  required Printable kind,
  required ScanPaper paper,
  required String name,
  required Directory directory,
  CalendarMonth? month,
  ByteData? font,
}) {
  final sheet = _sheet(paper, sideways: kind == Printable.calendar);
  final document = pw.Document(title: name, theme: _theme(font))
    ..addPage(
      pw.Page(
        pageFormat: sheet,
        build: (_) => switch (kind) {
          Printable.calendar => _calendar(month!),
          Printable.checklist => _checklist(sheet),
          Printable.lined || Printable.grid || Printable.dots => pw.CustomPaint(
            size: PdfPoint(sheet.availableWidth, sheet.availableHeight),
            painter: (canvas, size) => _ruled(canvas, size, kind),
          ),
        },
      ),
    );
  return _written(document, name, directory);
}

void _ruled(PdfGraphics canvas, PdfPoint size, Printable kind) {
  canvas
    ..setStrokeColor(_rule)
    ..setFillColor(_rule)
    ..setLineWidth(0.4);
  if (kind == Printable.lined) {
    const step = _ruleMm * PdfPageFormat.mm;
    for (var y = size.y - step; y >= 0; y -= step) {
      canvas.drawLine(0, y, size.x, y);
    }
    canvas.strokePath();
    return;
  }
  const step = _squareMm * PdfPageFormat.mm;
  // Whole squares only, so the last row and column are not cut short.
  final across = (size.x / step).floor();
  final down = (size.y / step).floor();
  for (var column = 0; column <= across; column++) {
    for (var row = 0; row <= down; row++) {
      if (kind == Printable.dots) {
        canvas.drawEllipse(column * step, size.y - row * step, 0.5, 0.5);
      }
    }
    if (kind == Printable.grid) {
      canvas.drawLine(
        column * step,
        size.y,
        column * step,
        size.y - down * step,
      );
    }
  }
  if (kind == Printable.dots) {
    canvas.fillPath();
    return;
  }
  for (var row = 0; row <= down; row++) {
    canvas.drawLine(0, size.y - row * step, across * step, size.y - row * step);
  }
  canvas.strokePath();
}

pw.Widget _checklist(PdfPageFormat sheet) {
  const row = 10 * PdfPageFormat.mm;
  const box = 5 * PdfPageFormat.mm;
  return pw.Column(
    children: [
      for (var i = 0; i < (sheet.availableHeight / row).floor(); i++)
        pw.SizedBox(
          height: row,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                width: box,
                height: box,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _rule, width: 0.8),
                ),
              ),
              pw.SizedBox(width: box),
              pw.Expanded(child: pw.Divider(color: _rule, thickness: 0.4)),
            ],
          ),
        ),
    ],
  );
}

pw.Widget _calendar(CalendarMonth month) {
  final first = DateTime(month.year, month.month);
  final days = DateTime(month.year, month.month + 1, 0).day;
  // How many boxes are empty before the first.
  final lead = (first.weekday - month.firstWeekday) % 7;
  final weeks = ((lead + days) / 7).ceil();
  final border = pw.Border.all(color: _rule, width: 0.5);

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Text(
        month.title,
        style: const pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 10),
      pw.Row(
        children: [
          for (final day in month.weekdays)
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(day, style: const pw.TextStyle(fontSize: 11)),
              ),
            ),
        ],
      ),
      for (var week = 0; week < weeks; week++)
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              for (var column = 0; column < 7; column++)
                pw.Expanded(
                  child: pw.Container(
                    decoration: pw.BoxDecoration(border: border),
                    padding: const pw.EdgeInsets.all(4),
                    child: switch (week * 7 + column - lead + 1) {
                      final day when day >= 1 && day <= days => pw.Text(
                        '$day',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      // Before the first of the month, or after its last.
                      _ => pw.SizedBox(),
                    },
                  ),
                ),
            ],
          ),
        ),
    ],
  );
}

/// How many of a document's pages can go on one sheet.
const List<int> pagesPerSheet = [2, 4];

/// [pages], PNG pictures of a document's pages, set [perSheet] to a
/// sheet, in order: two side by side on a sheet turned sideways, or four
/// in two rows.
Future<File> pagesOnSheets({
  required List<Uint8List> pages,
  required int perSheet,
  required ScanPaper paper,
  required String name,
  required Directory directory,
}) {
  final sheet = _sheet(paper, sideways: perSheet == 2);
  const gap = 5 * PdfPageFormat.mm;
  final pictures = [for (final page in pages) pw.MemoryImage(page)];
  final rows = perSheet == 2 ? 1 : 2;
  final document = pw.Document(title: name);

  for (var first = 0; first < pictures.length; first += perSheet) {
    final onSheet = pictures.skip(first).take(perSheet).toList();
    document.addPage(
      pw.Page(
        pageFormat: sheet,
        build: (_) => pw.Column(
          children: [
            for (var row = 0; row < rows; row++) ...[
              if (row > 0) pw.SizedBox(height: gap),
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    for (var column = 0; column < 2; column++) ...[
                      if (column > 0) pw.SizedBox(width: gap),
                      pw.Expanded(
                        child: switch (onSheet.elementAtOrNull(
                          row * 2 + column,
                        )) {
                          final picture? => pw.Center(child: pw.Image(picture)),
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
  return _written(document, name, directory);
}
