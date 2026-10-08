import 'dart:convert';
import 'dart:typed_data';

/// A page read back out of a raster file.
class ReadPage {
  const new({
    required this.header,
    required this.width,
    required this.height,
    required this.bytesPerPixel,
    required this.pixels,
  });

  final Uint8List header;
  final int width;
  final int height;
  final int bytesPerPixel;
  final Uint8List pixels;

  int uint32(int offset) => ByteData.sublistView(header).getUint32(offset);
  int int32(int offset) => ByteData.sublistView(header).getInt32(offset);
}

/// Reads a PWG Raster or Apple Raster file the way a printer does. It
/// shares no code with the encoder, so the two check each other, and the
/// files the operating system's own CUPS filters write check them both.
List<ReadPage> readRaster(Uint8List file) {
  final pwg = ascii.decode(file.sublist(0, 4)) == 'RaS2';
  var at = pwg ? 4 : 12;
  final pages = <ReadPage>[];

  while (at < file.length) {
    final headerLength = pwg ? 1796 : 32;
    final header = Uint8List.sublistView(file, at, at + headerLength);
    final data = ByteData.sublistView(header);
    at += headerLength;

    final width = data.getUint32(pwg ? 372 : 12);
    final height = data.getUint32(pwg ? 376 : 16);
    final size = (pwg ? data.getUint32(388) : header[0]) ~/ 8;
    final pixels = Uint8List(width * height * size);

    var row = 0;
    while (row < height) {
      final repeats = file[at++];
      final lineStart = row * width * size;
      var x = 0;
      while (x < width) {
        final code = file[at++];
        if (code <= 127) {
          for (var i = 0; i <= code; i++) {
            pixels.setRange(
              lineStart + x * size,
              lineStart + (x + 1) * size,
              file,
              at,
            );
            x++;
          }
          at += size;
        } else {
          final count = 257 - code;
          pixels.setRange(
            lineStart + x * size,
            lineStart + (x + count) * size,
            file,
            at,
          );
          x += count;
          at += count * size;
        }
      }
      for (var i = 1; i <= repeats; i++) {
        pixels.setRange(
          lineStart + i * width * size,
          lineStart + (i + 1) * width * size,
          pixels,
          lineStart,
        );
      }
      row += repeats + 1;
    }

    pages.add(
      ReadPage(
        header: header,
        width: width,
        height: height,
        bytesPerPixel: size,
        pixels: pixels,
      ),
    );
  }
  return pages;
}
