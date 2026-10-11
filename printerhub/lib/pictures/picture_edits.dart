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

/// A line drawn over a picture with a finger: the points it passed, in
/// parts of the picture's width and height.
typedef PictureStroke = List<Point<double>>;

/// How wide the highlighter is, as a part of the picture's shorter side.
const double highlighterWidth = 0.035;

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

/// [bytes] with [strokes] drawn over it as a highlighter draws: yellow
/// that the picture shows through, the same strength where lines cross.
Uint8List highlightedPicture(Uint8List bytes, List<PictureStroke> strokes) {
  final picture = _decoded(bytes);
  final pen = max(
    3,
    (min(picture.width, picture.height) * highlighterWidth).round(),
  );
  // Where the ink goes is drawn solid on a sheet of its own first, so a
  // place two lines pass over is inked once.
  final ink = img.Image(
    width: picture.width,
    height: picture.height,
    numChannels: 1,
  );
  final mark = img.ColorUint8(1)..r = 255;
  var left = picture.width;
  var top = picture.height;
  var right = 0;
  var bottom = 0;
  for (final stroke in strokes) {
    for (var i = 0; i < stroke.length; i++) {
      final x = (stroke[i].x * picture.width).round();
      final y = (stroke[i].y * picture.height).round();
      img.fillCircle(ink, x: x, y: y, radius: pen ~/ 2, color: mark);
      if (i > 0) {
        img.drawLine(
          ink,
          x1: (stroke[i - 1].x * picture.width).round(),
          y1: (stroke[i - 1].y * picture.height).round(),
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

  const strength = 0.45;
  for (var y = max(0, top); y < min(picture.height, bottom); y++) {
    for (var x = max(0, left); x < min(picture.width, right); x++) {
      if (ink.getPixel(x, y).r == 0) continue;
      final pixel = picture.getPixel(x, y);
      picture.setPixelRgb(
        x,
        y,
        pixel.r + (255 - pixel.r) * strength,
        pixel.g + (235 - pixel.g) * strength,
        pixel.b + (59 - pixel.b) * strength,
      );
    }
  }
  return _encoded(picture);
}
