import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// The two page-image formats driverless printers take.
enum RasterFormat {
  /// PWG Raster (PWG 5102.4). Every IPP Everywhere and Mopria printer.
  pwg('image/pwg-raster'),

  /// Apple Raster. Every AirPrint printer.
  urf('image/urf');

  new(this.mimeType);

  final String mimeType;
}

/// How a pixel is stored.
enum RasterColor {
  /// Three bytes: red, green, blue.
  srgb8(3),

  /// One byte: 0 is black, 255 is white.
  sgray8(1);

  new(this.bytesPerPixel);

  final int bytesPerPixel;
}

/// Which sides of the sheet are printed, and where the binding is.
enum RasterSides { oneSided, twoSidedLongEdge, twoSidedShortEdge }

/// How a printer wants the back of a sheet delivered. A printer that turns
/// the sheet over in its duplexer sees the back side upside down, mirrored,
/// or as it is, and says which.
enum SheetBack {
  normal,
  flipped,
  rotated,
  manualTumble;

  /// From `pwg-raster-document-sheet-back`. An unknown word is `normal`.
  static SheetBack fromKeyword(String? keyword) => switch (keyword) {
    'flipped' => flipped,
    'rotated' => rotated,
    'manual-tumble' => manualTumble,
    _ => normal,
  };
}

/// What every page of one document has in common.
@immutable
class RasterDocument {
  const new({
    required this.format,
    required this.color,
    required this.resolutionDpi,
    required this.widthPx,
    required this.heightPx,
    required this.pageCount,
    this.sides = RasterSides.oneSided,
    this.sheetBack = SheetBack.normal,
    this.quality,
    this.mediaName,
  });

  final RasterFormat format;
  final RasterColor color;
  final int resolutionDpi;
  final int widthPx;
  final int heightPx;
  final int pageCount;
  final RasterSides sides;
  final SheetBack sheetBack;

  /// 3 is draft, 4 normal, 5 high. Null leaves it to the printer.
  final int? quality;

  /// The PWG name of the paper, such as `iso_a4_210x297mm`.
  final String? mediaName;

  int get bytesPerLine => widthPx * color.bytesPerPixel;

  /// How many bytes [RasterEncoder.page] expects.
  int get bytesPerPage => bytesPerLine * heightPx;

  bool get _twoSided => sides != RasterSides.oneSided;

  /// True when the page at [index] (from 0) lands on the back of a sheet.
  bool isBackSide(int index) => _twoSided && index.isOdd;

  /// True when a back side must be mirrored left to right.
  bool get backMirrored => switch (sides) {
    RasterSides.oneSided => false,
    RasterSides.twoSidedLongEdge => sheetBack == SheetBack.rotated,
    RasterSides.twoSidedShortEdge =>
      sheetBack == SheetBack.flipped || sheetBack == SheetBack.manualTumble,
  };

  /// True when a back side must be turned top to bottom.
  bool get backUpsideDown => switch (sides) {
    RasterSides.oneSided => false,
    RasterSides.twoSidedLongEdge =>
      sheetBack == SheetBack.flipped || sheetBack == SheetBack.rotated,
    RasterSides.twoSidedShortEdge => sheetBack == SheetBack.manualTumble,
  };
}

/// Writes a document as PWG Raster or Apple Raster, a page at a time, so a
/// long document never sits in memory whole.
///
/// Send [start], then [page] for each page in order.
class RasterEncoder {
  new(this.document);

  final RasterDocument document;

  /// The bytes that open the file.
  Uint8List start() {
    if (document.format == RasterFormat.pwg) {
      return Uint8List.fromList(ascii.encode('RaS2'));
    }
    final out = Uint8List(12)..setAll(0, ascii.encode('UNIRAST'));
    ByteData.sublistView(out).setUint32(8, document.pageCount);
    return out;
  }

  /// One page: its header, then its compressed pixels.
  ///
  /// [pixels] holds the rows from the top, each row from the left, with
  /// nothing between them: [RasterDocument.bytesPerPage] bytes. A back side
  /// is turned the way the printer asks; pass every page upright.
  Uint8List page(Uint8List pixels, {required int index}) {
    if (pixels.length != document.bytesPerPage) {
      throw ArgumentError.value(
        pixels.length,
        'pixels',
        'A page is ${document.bytesPerPage} bytes',
      );
    }
    final back = document.isBackSide(index);
    final mirrored = back && document.backMirrored;
    final upsideDown = back && document.backUpsideDown;

    final out = BytesBuilder(copy: false)
      ..add(
        document.format == RasterFormat.pwg
            ? _pwgHeader(mirrored: mirrored, upsideDown: upsideDown)
            : _urfHeader(),
      );
    _compress(out, pixels, mirrored: mirrored, upsideDown: upsideDown);
    return out.takeBytes();
  }

  /// The 1796-byte page header of PWG 5102.4, which is the CUPS version 2
  /// header with some fields given new meanings.
  Uint8List _pwgHeader({required bool mirrored, required bool upsideDown}) {
    final header = Uint8List(1796);
    final data = ByteData.sublistView(header);
    final dpi = document.resolutionDpi;
    final twoSided = document.sides != RasterSides.oneSided;

    void text(int offset, String value) {
      final bytes = ascii.encode(value);
      header.setRange(offset, offset + bytes.length.clamp(0, 63), bytes);
    }

    text(0, 'PwgRaster');
    data
      ..setUint32(272, twoSided ? 1 : 0) // Duplex
      ..setUint32(276, dpi) // HWResolution, across
      ..setUint32(280, dpi) // HWResolution, down
      ..setUint32(340, 1) // NumCopies: copies are asked for in IPP
      ..setUint32(352, (document.widthPx * 72 / dpi).round()) // PageSize
      ..setUint32(356, (document.heightPx * 72 / dpi).round())
      ..setUint32(368, document.sides == RasterSides.twoSidedShortEdge ? 1 : 0)
      ..setUint32(372, document.widthPx)
      ..setUint32(376, document.heightPx)
      ..setUint32(384, 8) // BitsPerColor
      ..setUint32(388, document.color.bytesPerPixel * 8) // BitsPerPixel
      ..setUint32(392, document.bytesPerLine)
      ..setUint32(400, document.color == RasterColor.srgb8 ? 19 : 18)
      ..setUint32(420, document.color.bytesPerPixel) // NumColors
      ..setUint32(452, document.pageCount) // TotalPageCount
      ..setInt32(456, mirrored ? -1 : 1) // CrossFeedTransform
      ..setInt32(460, upsideDown ? -1 : 1) // FeedTransform
      ..setUint32(480, 0x00FFFFFF) // AlternatePrimary: white
      ..setUint32(484, document.quality ?? 0);
    final media = document.mediaName;
    if (media != null) text(1732, media); // PageSizeName
    return header;
  }

  /// The 32-byte page header of Apple Raster.
  Uint8List _urfHeader() {
    final header = Uint8List(32);
    header[0] = document.color.bytesPerPixel * 8;
    header[1] = document.color == RasterColor.srgb8 ? 1 : 0;
    header[2] = switch (document.sides) {
      RasterSides.oneSided => 1,
      RasterSides.twoSidedShortEdge => 2,
      RasterSides.twoSidedLongEdge => 3,
    };
    header[3] = document.quality ?? 0;
    ByteData.sublistView(header)
      ..setUint32(12, document.widthPx)
      ..setUint32(16, document.heightPx)
      ..setUint32(20, document.resolutionDpi);
    return header;
  }

  /// Both formats pack pixels the same way. Each group of identical lines
  /// is written once, after a count of how many more times it repeats. In a
  /// line, a count below 128 says the pixel after it repeats that many more
  /// times; a count above 128 says that 257 minus the count different pixels
  /// follow.
  void _compress(
    BytesBuilder out,
    Uint8List pixels, {
    required bool mirrored,
    required bool upsideDown,
  }) {
    final lineLength = document.bytesPerLine;
    final height = document.heightPx;
    final size = document.color.bytesPerPixel;
    final width = document.widthPx;

    int startOf(int row) => (upsideDown ? height - 1 - row : row) * lineLength;

    bool sameLine(int a, int b) {
      for (var i = 0; i < lineLength; i++) {
        if (pixels[a + i] != pixels[b + i]) return false;
      }
      return true;
    }

    final line = Uint8List(lineLength);
    // Room for the worst case: every pixel on its own, plus the counts.
    final packed = Uint8List(lineLength + (width / 128).ceil() + 1);

    var row = 0;
    while (row < height) {
      final start = startOf(row);
      var repeats = 0;
      while (row + repeats + 1 < height &&
          repeats < 255 &&
          sameLine(start, startOf(row + repeats + 1))) {
        repeats++;
      }

      if (mirrored) {
        for (var x = 0; x < width; x++) {
          final from = start + (width - 1 - x) * size;
          line.setRange(x * size, x * size + size, pixels, from);
        }
      } else {
        line.setRange(0, lineLength, pixels, start);
      }

      // Copied, because the builder keeps what it is given and `packed` is
      // used again for the next line.
      out
        ..addByte(repeats)
        ..add(packed.sublist(0, _packLine(line, size, packed)));
      row += repeats + 1;
    }
  }

  /// Packs one [line] of pixels [size] bytes wide into [out] and returns
  /// how many bytes it wrote.
  static int _packLine(Uint8List line, int size, Uint8List out) {
    final count = line.length ~/ size;

    bool same(int a, int b) {
      for (var i = 0; i < size; i++) {
        if (line[a * size + i] != line[b * size + i]) return false;
      }
      return true;
    }

    var at = 0;
    var written = 0;
    while (at < count) {
      var run = 1;
      while (at + run < count && run < 128 && same(at, at + run)) {
        run++;
      }
      if (run > 1 || at + 1 == count) {
        out[written++] = run - 1;
        out.setRange(written, written + size, line, at * size);
        written += size;
        at += run;
        continue;
      }

      // Pixels that differ from their neighbour, up to where a run begins.
      var different = 1;
      while (at + different < count &&
          different < 128 &&
          (at + different + 1 == count ||
              !same(at + different, at + different + 1))) {
        different++;
      }
      // One pixel on its own is a run of one.
      out[written++] = different == 1 ? 0 : 257 - different;
      out.setRange(written, written + different * size, line, at * size);
      written += different * size;
      at += different;
    }
    return written;
  }
}
