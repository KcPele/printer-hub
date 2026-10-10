// Draws pages with the phone's own PDF and image code, through plugins
// that only exist on a device. What is done with the pixels is decided in
// `printer_protocols`, which is tested.
// coverage:ignore-file

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:printerhub/print/documents.dart';
import 'package:printers_repository/printers_repository.dart';
import 'package:printing/printing.dart';

class PrintingPageRenderer implements PageRenderer {
  const new();

  /// Low enough to count the pages of a long document quickly, high enough
  /// for the first to be recognised.
  static const double _previewDpi = 40;

  @override
  Future<DocumentPreview> preview(PickedDocument document) async {
    final bytes = await File(document.path).readAsBytes();
    if (document.mimeType != 'application/pdf') {
      // A picture is one page, and its own preview.
      await _decode(bytes);
      return DocumentPreview(pageCount: 1, firstPage: bytes);
    }

    var pages = 0;
    Uint8List? first;
    await for (final page in Printing.raster(bytes, dpi: _previewDpi)) {
      first ??= await page.toPng();
      pages++;
    }
    if (pages == 0) throw const FormatException('The PDF has no pages.');
    return DocumentPreview(pageCount: pages, firstPage: first);
  }

  @override
  Stream<Uint8List> rasterise(
    PickedDocument document,
    RasterDocument page,
  ) async* {
    final bytes = await File(document.path).readAsBytes();
    if (document.mimeType == 'application/pdf') {
      await for (final drawn in Printing.raster(
        bytes,
        dpi: page.resolutionDpi.toDouble(),
      )) {
        yield rasterPageFromRgba(
          drawn.pixels,
          width: drawn.width,
          height: drawn.height,
          document: page,
        );
      }
      return;
    }

    // A picture is made as large as fits on the sheet, keeping its shape.
    final natural = await _decode(bytes);
    final scale = [
      page.widthPx / natural.width,
      page.heightPx / natural.height,
    ].reduce((a, b) => a < b ? a : b);
    final width = (natural.width * scale).round().clamp(1, page.widthPx);
    final height = (natural.height * scale).round().clamp(1, page.heightPx);
    natural.dispose();

    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: width,
      targetHeight: height,
    );
    final image = (await codec.getNextFrame()).image;
    final rgba = await image.toByteData();
    image.dispose();
    yield rasterPageFromRgba(
      rgba!.buffer.asUint8List(),
      width: width,
      height: height,
      document: page,
    );
  }

  @override
  Stream<Uint8List> pictures(PickedDocument document, {int dpi = 150}) async* {
    final bytes = await File(document.path).readAsBytes();
    if (document.mimeType != 'application/pdf') {
      final image = await _decode(bytes);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      yield png!.buffer.asUint8List();
      return;
    }
    await for (final page in Printing.raster(bytes, dpi: dpi.toDouble())) {
      yield await page.toPng();
    }
  }

  @override
  Future<bool> systemPrint(PickedDocument document) async {
    final bytes = await File(document.path).readAsBytes();
    return await Printing.layoutPdf(
      name: document.name,
      onLayout: (_) => bytes,
    );
  }

  static Future<ui.Image> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    return (await codec.getNextFrame()).image;
  }
}
