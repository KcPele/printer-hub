import 'dart:math';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:image/image.dart' as img;

/// The part of a picture that is kept when it is cropped, in parts of its
/// width and height from its top left corner: 0 to 1.
class CropBox extends Equatable {
  const new({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  /// The whole picture, with a little taken off each edge to begin from.
  static const CropBox start = CropBox(
    left: 0.08,
    top: 0.08,
    right: 0.92,
    bottom: 0.92,
  );

  /// The least of a picture a crop keeps, each way.
  static const double least = 0.1;

  final double left;
  final double top;
  final double right;
  final double bottom;

  /// This box with its edges moved, kept inside the picture and never
  /// smaller than [least]. An edge that would cross the one opposite
  /// stops short of it.
  CropBox moved({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) {
    final newLeft = (this.left + left).clamp(0.0, this.right - least);
    final newTop = (this.top + top).clamp(0.0, this.bottom - least);
    return CropBox(
      left: newLeft,
      top: newTop,
      right: (this.right + right).clamp(newLeft + least, 1.0),
      bottom: (this.bottom + bottom).clamp(newTop + least, 1.0),
    );
  }

  /// This box carried across the picture without changing its size.
  CropBox carried(double across, double down) {
    final dx = across.clamp(-left, 1 - right);
    final dy = down.clamp(-top, 1 - bottom);
    return CropBox(
      left: left + dx,
      top: top + dy,
      right: right + dx,
      bottom: bottom + dy,
    );
  }

  @override
  List<Object?> get props => [left, top, right, bottom];
}

/// The inks a highlighter comes in. They are the colours of real pens,
/// the same in every theme.
enum HighlightColor {
  yellow(255, 235, 59),
  green(105, 240, 174),
  pink(255, 128, 171),
  blue(64, 196, 255),
  orange(255, 171, 64);

  new(this.r, this.g, this.b);

  /// How much red, green, and blue is in it, each 0 to 255.
  final int r;
  final int g;
  final int b;
}

/// The two highlighters: one for a line of small print, one for a
/// heading or a whole paragraph.
enum HighlightPen {
  thin(0.018),
  thick(0.045);

  new(this.width);

  /// How wide it draws, as a part of the picture's shorter side.
  final double width;
}

/// A line drawn over a picture with a finger: the points it passed, in
/// parts of the picture's width and height, and the pen it was drawn
/// with.
class PictureStroke extends Equatable {
  const new({
    required this.points,
    this.color = HighlightColor.yellow,
    this.pen = HighlightPen.thick,
  });

  final List<Point<double>> points;
  final HighlightColor color;
  final HighlightPen pen;

  /// This line carried on to [point].
  PictureStroke to(Point<double> point) =>
      PictureStroke(points: [...points, point], color: color, pen: pen);

  @override
  List<Object?> get props => [points, color, pen];
}

/// How wide and tall a picture is, or null when [bytes] is not a picture.
({int width, int height})? pictureSize(Uint8List bytes) {
  try {
    final info = img.findDecoderForData(bytes)?.startDecode(bytes);
    return info == null ? null : (width: info.width, height: info.height);
  } on Object {
    return null;
  }
}

img.Image _decoded(Uint8List bytes) {
  // A phone's photo says which way up it is in a note beside the pixels.
  // The pixels are turned to match, so what is cut is what was seen.
  return img.bakeOrientation(img.decodeImage(bytes)!);
}

Uint8List _encoded(img.Image picture) => img.encodeJpg(picture, quality: 92);

/// [bytes] cut down to [box], as a JPEG.
Uint8List croppedPicture(Uint8List bytes, CropBox box) {
  final picture = _decoded(bytes);
  final x = (box.left * picture.width).round();
  final y = (box.top * picture.height).round();
  return _encoded(
    img.copyCrop(
      picture,
      x: x,
      y: y,
      width: max(1, (box.right * picture.width).round() - x),
      height: max(1, (box.bottom * picture.height).round() - y),
    ),
  );
}

/// [bytes] turned a quarter turn to the right, as a JPEG.
Uint8List turnedPicture(Uint8List bytes) {
  return _encoded(img.copyRotate(_decoded(bytes), angle: 90));
}

/// [bytes] with [strokes] drawn over it as a highlighter draws: ink that
/// the picture shows through, the same strength where lines of one
/// colour cross.
Uint8List highlightedPicture(Uint8List bytes, List<PictureStroke> strokes) {
  final picture = _decoded(bytes);
  final shorter = min(picture.width, picture.height);
  final mark = img.ColorUint8(1)..r = 255;
  const strength = 0.45;

  for (final color in HighlightColor.values) {
    final inked = [
      for (final stroke in strokes)
        if (stroke.color == color) stroke,
    ];
    if (inked.isEmpty) continue;
    // Where this ink goes is drawn solid on a sheet of its own first, so
    // a place two lines pass over is inked once.
    final ink = img.Image(
      width: picture.width,
      height: picture.height,
      numChannels: 1,
    );
    var left = picture.width;
    var top = picture.height;
    var right = 0;
    var bottom = 0;
    for (final stroke in inked) {
      final pen = max(3, (shorter * stroke.pen.width).round());
      final points = stroke.points;
      for (var i = 0; i < points.length; i++) {
        final x = (points[i].x * picture.width).round();
        final y = (points[i].y * picture.height).round();
        img.fillCircle(ink, x: x, y: y, radius: pen ~/ 2, color: mark);
        if (i > 0) {
          img.drawLine(
            ink,
            x1: (points[i - 1].x * picture.width).round(),
            y1: (points[i - 1].y * picture.height).round(),
            x2: x,
            y2: y,
            color: mark,
            thickness: pen,
          );
        }
        left = min(left, x - pen);
        top = min(top, y - pen);
        right = max(right, x + pen);
        bottom = max(bottom, y + pen);
      }
    }

    for (var y = max(0, top); y < min(picture.height, bottom); y++) {
      for (var x = max(0, left); x < min(picture.width, right); x++) {
        if (ink.getPixel(x, y).r == 0) continue;
        final pixel = picture.getPixel(x, y);
        picture.setPixelRgb(
          x,
          y,
          pixel.r + (color.r - pixel.r) * strength,
          pixel.g + (color.g - pixel.g) * strength,
          pixel.b + (color.b - pixel.b) * strength,
        );
      }
    }
  }
  return _encoded(picture);
}
