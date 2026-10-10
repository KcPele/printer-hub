import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:image/image.dart' as img;
import 'package:local_store/local_store.dart';

/// One line of a signature as it was drawn: the points the finger passed.
typedef SignatureStroke = List<Point<double>>;

/// A signature set on a page of a scan: the picture of it, and where.
///
/// The place is in parts of the sheet, from its top left corner, so the
/// same placement fits any paper size.
class PlacedSignature extends Equatable {
  const new({
    required this.png,
    required this.page,
    required this.x,
    required this.y,
    required this.width,
  });

  /// The signature, dark on nothing, as a PNG.
  final Uint8List png;

  /// Which sheet it is on, counting from zero.
  final int page;

  /// How far across and down its top left corner is: 0 to 1.
  final double x;
  final double y;

  /// How wide it is, as a part of the sheet's width.
  final double width;

  @override
  List<Object?> get props => [png.length, page, x, y, width];
}

/// Keeps the person's signature on this phone, where other apps cannot
/// read it. It is never sent to the API: only a document it was set on
/// leaves the phone, and only when the person keeps or shares it.
class SignatureStore {
  const new({required this._store});

  final SecureStore _store;

  static const String _key = 'signature.png';

  /// The signature kept, or null when there is none.
  Future<Uint8List?> read() async {
    final kept = await _store.read(_key);
    if (kept == null) return null;
    try {
      return base64Decode(kept);
    } on FormatException {
      return null;
    }
  }

  Future<void> save(Uint8List png) => _store.write(_key, base64Encode(png));

  Future<void> clear() => _store.delete(_key);
}

/// How wide a signature's picture is to its height, or null when [png] is
/// not a picture.
double? signatureAspect(Uint8List png) {
  final img.Image? picture;
  try {
    picture = img.decodePng(png);
  } on Object {
    return null;
  }
  if (picture == null || picture.height == 0) return null;
  return picture.width / picture.height;
}

/// Draws [strokes], as they were made on a pad [width] by [height], as a
/// PNG: dark ink on nothing, cut close to the ink.
///
/// Null when nothing was drawn.
Uint8List? signaturePng(
  List<SignatureStroke> strokes, {
  required double width,
  required double height,
}) {
  final points = [for (final stroke in strokes) ...stroke];
  if (points.isEmpty) return null;

  // Drawn at twice the pad's size, so it stays sharp when printed.
  const scale = 2;
  const pen = 5;
  final picture = img.Image(
    width: (width * scale).ceil(),
    height: (height * scale).ceil(),
    numChannels: 4,
  );
  final ink = img.ColorRgba8(20, 20, 20, 255);
  for (final stroke in strokes) {
    for (final point in stroke) {
      img.fillCircle(
        picture,
        x: (point.x * scale).round(),
        y: (point.y * scale).round(),
        radius: pen ~/ 2,
        color: ink,
      );
    }
    for (var i = 1; i < stroke.length; i++) {
      img.drawLine(
        picture,
        x1: (stroke[i - 1].x * scale).round(),
        y1: (stroke[i - 1].y * scale).round(),
        x2: (stroke[i].x * scale).round(),
        y2: (stroke[i].y * scale).round(),
        color: ink,
        thickness: pen,
      );
    }
  }

  // Cut to the ink, with a little room around it.
  const room = pen * 2;
  final left = (points.map((p) => p.x).reduce(min) * scale).floor() - room;
  final top = (points.map((p) => p.y).reduce(min) * scale).floor() - room;
  final right = (points.map((p) => p.x).reduce(max) * scale).ceil() + room;
  final bottom = (points.map((p) => p.y).reduce(max) * scale).ceil() + room;
  final x = left.clamp(0, picture.width - 1);
  final y = top.clamp(0, picture.height - 1);
  final cut = img.copyCrop(
    picture,
    x: x,
    y: y,
    width: (right - x).clamp(1, picture.width - x),
    height: (bottom - y).clamp(1, picture.height - y),
  );
  return img.encodePng(cut);
}
