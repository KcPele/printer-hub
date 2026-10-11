import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:printerhub/pictures/pictures.dart';

import '../helpers/helpers.dart';

/// A plain grey picture.
Uint8List grey({int width = 40, int height = 20}) => img.encodeJpg(
  img.fill(
    img.Image(width: width, height: height),
    color: img.ColorRgb8(128, 128, 128),
  ),
);

void main() {
  group('CropBox', () {
    test('begins a little inside the picture', () {
      expect(CropBox.start.left, greaterThan(0));
      expect(CropBox.start.bottom, lessThan(1));
    });

    test('moves its edges, and stops them at the picture’s', () {
      final box = CropBox.start.moved(left: 0.1, bottom: -0.2);
      expect(box.left, closeTo(0.18, 1e-9));
      expect(box.bottom, closeTo(0.72, 1e-9));
      expect(box.top, CropBox.start.top);

      final wide = CropBox.start.moved(left: -1, top: -1, right: 1, bottom: 1);
      expect(wide, const CropBox(left: 0, top: 0, right: 1, bottom: 1));
    });

    test('never lets an edge cross the one opposite', () {
      final box = CropBox.start.moved(left: 2, top: 2);
      expect(box.right - box.left, closeTo(CropBox.least, 1e-9));
      expect(box.bottom - box.top, closeTo(CropBox.least, 1e-9));

      final other = CropBox.start.moved(right: -2, bottom: -2);
      expect(other.right - other.left, closeTo(CropBox.least, 1e-9));
      expect(other.bottom - other.top, closeTo(CropBox.least, 1e-9));
    });

    test('is carried across the picture without changing size', () {
      final box = CropBox.start.carried(0.02, -0.03);
      expect(box.left, closeTo(0.10, 1e-9));
      expect(box.top, closeTo(0.05, 1e-9));
      expect(box.right - box.left, closeTo(0.84, 1e-9));

      // And stops at the picture's edge.
      final far = CropBox.start.carried(5, 5);
      expect(far.right, 1);
      expect(far.bottom, 1);
      expect(far.right - far.left, closeTo(0.84, 1e-9));
    });
  });

  group('pictureSize', () {
    test('says how wide and tall a picture is', () {
      expect(pictureSize(grey()), (width: 40, height: 20));
      expect(pictureSize(tinyPng), (width: 2, height: 2));
    });

    test('is null for what is not a picture', () {
      expect(pictureSize(Uint8List.fromList([1, 2, 3, 4])), isNull);
      // A picture that was cut short.
      expect(pictureSize(Uint8List.sublistView(tinyPng, 0, 12)), isNull);
    });
  });

  test('highlights in the ink and the width of each pen', () {
    final marked = img.decodeJpg(
      highlightedPicture(grey(width: 400, height: 400), [
        const PictureStroke(
          points: [Point(0.1, 0.25), Point(0.9, 0.25)],
          color: HighlightColor.blue,
          pen: HighlightPen.thin,
        ),
        const PictureStroke(points: [Point(0.1, 0.75), Point(0.9, 0.75)]),
      ]),
    )!;

    // Blue above: more blue than red. Yellow below: the other way.
    final blue = marked.getPixel(200, 100);
    expect(blue.b, greaterThan(blue.r + 30));
    final yellow = marked.getPixel(200, 300);
    expect(yellow.r, greaterThan(yellow.b + 30));
    // Seven pixels from its middle, the thick line is still there and the
    // thin one is not.
    expect(marked.getPixel(200, 307).b, lessThan(110));
    expect(marked.getPixel(200, 107).b, closeTo(128, 12));
    expect(HighlightPen.thin.width, lessThan(HighlightPen.thick.width));
  });

  test('a line is carried on in the same pen, and compares by value', () {
    const line = PictureStroke(
      points: [Point(0.1, 0.1)],
      color: HighlightColor.pink,
      pen: HighlightPen.thin,
    );
    final longer = line.to(const Point(0.2, 0.2));

    expect(longer.points, hasLength(2));
    expect(longer.color, HighlightColor.pink);
    expect(longer.pen, HighlightPen.thin);
    expect(longer, isNot(line));
    expect(
      line,
      const PictureStroke(
        points: [Point(0.1, 0.1)],
        color: HighlightColor.pink,
        pen: HighlightPen.thin,
      ),
    );
  });

  test('crops a picture to the box', () {
    final cropped = img.decodeJpg(
      croppedPicture(
        grey(),
        const CropBox(left: 0.25, top: 0.5, right: 0.75, bottom: 1),
      ),
    )!;

    expect((cropped.width, cropped.height), (20, 10));
  });

  test('turns a picture a quarter turn', () {
    final turned = img.decodeJpg(turnedPicture(grey()))!;

    expect((turned.width, turned.height), (20, 40));
  });

  test('highlights where the lines went, the same where they cross, and '
      'nowhere else', () {
    final marked = img.decodeJpg(
      highlightedPicture(grey(width: 200, height: 200), [
        const PictureStroke(points: [Point(0.2, 0.5), Point(0.8, 0.5)]),
        const PictureStroke(points: [Point(0.5, 0.2), Point(0.5, 0.8)]),
      ]),
    )!;

    final onLine = marked.getPixel(60, 100);
    final crossing = marked.getPixel(100, 100);
    final away = marked.getPixel(20, 20);
    // Yellow: more red and green than before, less blue.
    expect(onLine.r, greaterThan(160));
    expect(onLine.g, greaterThan(160));
    expect(onLine.b, lessThan(110));
    // A thin line's colour is softened at its edges when it is saved.
    expect(crossing.r, closeTo(onLine.r, 20));
    expect(crossing.b, closeTo(onLine.b, 20));
    expect(away.r, closeTo(128, 4));
    expect(away.b, closeTo(128, 4));
  });
}
