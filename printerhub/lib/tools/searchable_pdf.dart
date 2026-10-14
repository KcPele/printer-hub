import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printerhub/scan/scan_output.dart';

/// A page of a searchable PDF: its picture, and the lines of words read
/// in it.
typedef ReadPage = ({Uint8List picture, List<TextLine> lines});

/// [pages] as a PDF that looks as the pictures do and holds their words:
/// each line is laid, unseen, over the place it was read, so the PDF can
/// be searched and its words picked out and copied. Written to
/// [directory].
///
/// Each page is as wide as a sheet of A4 and as tall as its picture's
/// shape makes it. [font] sets the words, so letters beyond plain Latin
/// are kept; without one only plain Latin is.
Future<File> searchablePdf({
  required List<ReadPage> pages,
  required String name,
  required Directory directory,
  ByteData? font,
}) async {
  final words = font == null ? null : pw.Font.ttf(font);
  final document = pw.Document(title: name);
  for (final page in pages) {
    final picture = pw.MemoryImage(page.picture);
    final width = PdfPageFormat.a4.width;
    final height = width * (picture.height ?? 1) / (picture.width ?? 1);
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(width, height),
        build: (_) => pw.Stack(
          children: [
            pw.Positioned.fill(child: pw.Image(picture, fit: pw.BoxFit.fill)),
            for (final line in page.lines)
              if (line.text.trim().isNotEmpty &&
                  line.width > 0 &&
                  line.height > 0)
                pw.Positioned(
                  left: line.left * width,
                  top: line.top * height,
                  child: pw.SizedBox(
                    width: line.width * width,
                    height: line.height * height,
                    // Stretched to the line's own box, so picking words
                    // out picks the words that are seen.
                    child: pw.FittedBox(
                      fit: pw.BoxFit.fill,
                      child: pw.Text(
                        line.text,
                        style: pw.TextStyle(
                          font: words,
                          fontSize: 10,
                          renderingMode: PdfTextRenderingMode.invisible,
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
  final file = File('${directory.path}/${scanFileName(name)}.pdf');
  await file.writeAsBytes(await document.save(), flush: true);
  return file;
}
