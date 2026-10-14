import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Where a photo of an open book is split: the fold between its pages,
/// as a part of the picture's width.
///
/// The fold is looked for near the middle, where a book's gutter falls,
/// as the darkest upright line there: the shadow the pages make where
/// they meet. A picture with no shadow is split down the middle.
double gutterOf(img.Image picture) {
  // Looked at small: the fold is found as well, and much sooner.
  final small = picture.width > 240
      ? img.copyResize(picture, width: 240)
      : picture;
  final from = (small.width * 0.4).floor();
  final to = (small.width * 0.6).ceil();
  // How light each upright line is, on average, across the middle.
  final lightness = [
    for (var x = from; x < to; x++)
      [
            for (var y = 0; y < small.height; y++)
              small.getPixel(x, y).luminance.toDouble(),
          ].reduce((a, b) => a + b) /
          small.height,
  ];
  final least = lightness.reduce(min);
  // A plain band has no fold to find.
  if (lightness.reduce(max) - least < 6) return 0.5;
  return (from + lightness.indexOf(least) + 0.5) / small.width;
}

/// A photo of an open book, split at its fold into its left page and its
/// right page, each a JPEG.
(Uint8List, Uint8List) splitSpread(Uint8List bytes) {
  final picture = img.bakeOrientation(img.decodeImage(bytes)!);
  final at = (gutterOf(picture) * picture.width).round().clamp(
    1,
    picture.width - 1,
  );
  Uint8List part(int x, int width) => img.encodeJpg(
    img.copyCrop(picture, x: x, y: 0, width: width, height: picture.height),
    quality: 90,
  );
  return (part(0, at), part(at, picture.width - at));
}
