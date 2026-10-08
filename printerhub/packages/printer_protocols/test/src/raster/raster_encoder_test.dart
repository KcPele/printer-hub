import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:printer_protocols/printer_protocols.dart';
import 'package:test/test.dart';

import '../../helpers/raster_reader.dart';

/// Two pages of 40 by 30 pixels, and the same pages as written by the
/// `rastertopwg` filter that ships with macOS.
Uint8List _fixture(String name) {
  return File('test/fixtures/raster/$name').readAsBytesSync();
}

RasterDocument _document(
  RasterFormat format,
  RasterColor color, {
  RasterSides sides = RasterSides.twoSidedLongEdge,
  SheetBack sheetBack = SheetBack.normal,
  int pageCount = 0,
  int width = 40,
  int height = 30,
  String? mediaName,
}) {
  return RasterDocument(
    format: format,
    color: color,
    resolutionDpi: 300,
    widthPx: width,
    heightPx: height,
    pageCount: pageCount,
    sides: sides,
    sheetBack: sheetBack,
    mediaName: mediaName,
  );
}

Uint8List _encode(RasterDocument document, Uint8List raw) {
  final encoder = RasterEncoder(document);
  final out = BytesBuilder()..add(encoder.start());
  final size = document.bytesPerPage;
  for (var i = 0; i * size < raw.length; i++) {
    out.add(encoder.page(raw.sublist(i * size, (i + 1) * size), index: i));
  }
  return out.toBytes();
}

void main() {
  group('RasterEncoder writes what the system filter writes', () {
    for (final (name, color) in [
      ('rgb', RasterColor.srgb8),
      ('gray', RasterColor.sgray8),
    ]) {
      test('PWG Raster, $name', () {
        final raw = _fixture('$name.raw');
        expect(
          _encode(
            _document(
              RasterFormat.pwg,
              color,
              // The filter names a size it does not know after its
              // measurements.
              mediaName: 'custom_3.38x2.53mm_3.38x2.53mm',
            ),
            raw,
          ),
          _fixture('$name.pwg'),
        );
      });

      test('Apple Raster, $name', () {
        final raw = _fixture('$name.raw');
        expect(
          _encode(_document(RasterFormat.urf, color), raw),
          _fixture('$name.urf'),
        );
      });
    }
  });

  group('RasterEncoder', () {
    test('names the formats by their MIME type', () {
      expect(RasterFormat.pwg.mimeType, 'image/pwg-raster');
      expect(RasterFormat.urf.mimeType, 'image/urf');
    });

    test('the reference files read back as the pixels they came from', () {
      for (final name in ['rgb', 'gray']) {
        for (final extension in ['pwg', 'urf']) {
          final pages = readRaster(_fixture('$name.$extension'));
          expect(
            [...pages[0].pixels, ...pages[1].pixels],
            _fixture('$name.raw'),
            reason: '$name.$extension',
          );
        }
      }
    });

    test('says how many pages follow, and what they are', () {
      const document = RasterDocument(
        format: RasterFormat.urf,
        color: RasterColor.sgray8,
        resolutionDpi: 600,
        widthPx: 4,
        heightPx: 2,
        pageCount: 3,
        sides: RasterSides.twoSidedShortEdge,
        quality: 5,
      );
      final encoder = RasterEncoder(document);

      expect(encoder.start(), [...ascii.encode('UNIRAST'), 0, 0, 0, 0, 3]);
      final page = readRaster(
        Uint8List.fromList([
          ...encoder.start(),
          ...encoder.page(Uint8List(8), index: 0),
        ]),
      ).single;
      expect(page.header.sublist(0, 4), [8, 0, 2, 5]);
      expect(page.uint32(20), 600);
    });

    test('describes the page in a PWG header', () {
      const document = RasterDocument(
        format: RasterFormat.pwg,
        color: RasterColor.srgb8,
        resolutionDpi: 300,
        widthPx: 2480,
        heightPx: 3508,
        pageCount: 2,
        sides: RasterSides.twoSidedShortEdge,
        quality: 4,
        mediaName: 'iso_a4_210x297mm',
      );
      final bytes = RasterEncoder(document).page(
        Uint8List(document.bytesPerPage)..fillRange(0, 2480 * 3, 255),
        index: 0,
      );
      final header = ReadPage(
        header: Uint8List.sublistView(bytes, 0, 1796),
        width: 0,
        height: 0,
        bytesPerPixel: 0,
        pixels: Uint8List(0),
      );

      expect(ascii.decode(bytes.sublist(0, 9)), 'PwgRaster');
      expect(header.uint32(272), 1, reason: 'Duplex');
      expect(header.uint32(368), 1, reason: 'Tumble');
      expect([header.uint32(352), header.uint32(356)], [595, 842]);
      expect([header.uint32(372), header.uint32(376)], [2480, 3508]);
      expect(header.uint32(392), 2480 * 3, reason: 'BytesPerLine');
      expect(header.uint32(400), 19, reason: 'sRGB');
      expect(header.uint32(452), 2, reason: 'TotalPageCount');
      expect(header.uint32(484), 4, reason: 'PrintQuality');
      expect(ascii.decode(bytes.sublist(1732, 1732 + 16)), 'iso_a4_210x297mm');
      // A blank A4 page packs down to almost nothing.
      expect(bytes.length, lessThan(1796 + 3000));
      expect(document.bytesPerPage, 2480 * 3508 * 3);
    });

    test('packs long runs, long stretches without runs, and lone pixels', () {
      // One pixel before a pair, 300 of one value, 300 that all differ, one
      // more, then a pair.
      final line = Uint8List.fromList([
        3,
        4,
        4,
        ...List.filled(300, 9),
        for (var i = 0; i < 300; i++)
          if (i.isEven) 1 else 2,
        7,
        5,
        5,
      ]);
      final document = _document(
        RasterFormat.pwg,
        RasterColor.sgray8,
        sides: RasterSides.oneSided,
        width: line.length,
        height: 1,
      );

      final page = readRaster(_encode(document, line)).single;

      expect(page.pixels, line);
    });

    test('writes a group of more than 256 identical lines in parts', () {
      final document = _document(
        RasterFormat.urf,
        RasterColor.sgray8,
        sides: RasterSides.oneSided,
        width: 3,
        height: 600,
      );
      final raw = Uint8List(document.bytesPerPage)..fillRange(0, 1800, 200);

      final bytes = _encode(document, raw);

      expect(readRaster(bytes).single.pixels, raw);
      // 12 to open the file, 32 for the page, and three groups of lines.
      expect(bytes.length, 12 + 32 + 3 * 3);
    });

    test('refuses a page of the wrong size', () {
      final encoder = RasterEncoder(
        _document(RasterFormat.pwg, RasterColor.srgb8),
      );

      expect(() => encoder.page(Uint8List(10), index: 0), throwsArgumentError);
    });
  });

  group('the back of a sheet', () {
    // Two rows of two pixels: 1 2 over 3 4.
    final upright = Uint8List.fromList([1, 2, 3, 4]);

    ReadPage back(RasterSides sides, SheetBack sheetBack, RasterFormat format) {
      final document = _document(
        format,
        RasterColor.sgray8,
        sides: sides,
        sheetBack: sheetBack,
        width: 2,
        height: 2,
      );
      final encoder = RasterEncoder(document);
      return readRaster(
        Uint8List.fromList([
          ...encoder.start(),
          ...encoder.page(upright, index: 1),
        ]),
      ).single;
    }

    test('is left alone on a printer that wants it as it is', () {
      for (final sides in RasterSides.values) {
        final page = back(sides, SheetBack.normal, RasterFormat.pwg);
        expect(page.pixels, upright);
        expect([page.int32(456), page.int32(460)], [1, 1]);
      }
    });

    test('is never turned when printing one side', () {
      for (final sheetBack in SheetBack.values) {
        expect(
          back(RasterSides.oneSided, sheetBack, RasterFormat.urf).pixels,
          upright,
        );
      }
    });

    test('is turned as the printer asks, bound on the long edge', () {
      const sides = RasterSides.twoSidedLongEdge;

      final flipped = back(sides, SheetBack.flipped, RasterFormat.pwg);
      expect(flipped.pixels, [3, 4, 1, 2]);
      expect([flipped.int32(456), flipped.int32(460)], [1, -1]);

      final rotated = back(sides, SheetBack.rotated, RasterFormat.pwg);
      expect(rotated.pixels, [4, 3, 2, 1]);
      expect([rotated.int32(456), rotated.int32(460)], [-1, -1]);

      expect(back(sides, SheetBack.manualTumble, RasterFormat.urf).pixels, [
        1,
        2,
        3,
        4,
      ]);
    });

    test('is turned as the printer asks, bound on the short edge', () {
      const sides = RasterSides.twoSidedShortEdge;

      final flipped = back(sides, SheetBack.flipped, RasterFormat.pwg);
      expect(flipped.pixels, [2, 1, 4, 3]);
      expect([flipped.int32(456), flipped.int32(460)], [-1, 1]);

      expect(back(sides, SheetBack.rotated, RasterFormat.urf).pixels, upright);
      expect(back(sides, SheetBack.manualTumble, RasterFormat.urf).pixels, [
        4,
        3,
        2,
        1,
      ]);
    });

    test('mirrors whole pixels, not bytes, in colour', () {
      final document = _document(
        RasterFormat.pwg,
        RasterColor.srgb8,
        sides: RasterSides.twoSidedShortEdge,
        sheetBack: SheetBack.flipped,
        width: 2,
        height: 1,
      );
      final bytes = Uint8List.fromList([
        ...RasterEncoder(document).start(),
        ...RasterEncoder(document)
            .page(Uint8List.fromList([1, 2, 3, 4, 5, 6]), index: 1),
      ]);

      expect(readRaster(bytes).single.pixels, [4, 5, 6, 1, 2, 3]);
    });

    test('front sides are never turned', () {
      final document = _document(
        RasterFormat.pwg,
        RasterColor.sgray8,
        sheetBack: SheetBack.rotated,
        width: 2,
        height: 2,
      );
      final bytes = Uint8List.fromList([
        ...RasterEncoder(document).start(),
        ...RasterEncoder(document).page(upright, index: 2),
      ]);

      expect(readRaster(bytes).single.pixels, upright);
    });

    test('reads the word a printer uses for it', () {
      expect(SheetBack.fromKeyword('flipped'), SheetBack.flipped);
      expect(SheetBack.fromKeyword('rotated'), SheetBack.rotated);
      expect(SheetBack.fromKeyword('manual-tumble'), SheetBack.manualTumble);
      expect(SheetBack.fromKeyword('normal'), SheetBack.normal);
      expect(SheetBack.fromKeyword(null), SheetBack.normal);
    });
  });
}
