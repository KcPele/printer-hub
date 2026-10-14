import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:printerhub/scan/spread.dart';

void main() {
  /// A light spread [width] wide, with a dark fold at [fold] when given.
  img.Image spread({int width = 400, double? fold}) {
    final picture = img.fill(
      img.Image(width: width, height: 200),
      color: img.ColorRgb8(240, 240, 240),
    );
    if (fold != null) {
      final x = (fold * width).round();
      img.fillRect(
        picture,
        x1: x - 2,
        y1: 0,
        x2: x + 2,
        y2: 199,
        color: img.ColorRgb8(40, 40, 40),
      );
    }
    return picture;
  }

  test('finds the fold where the shadow is, near the middle', () {
    expect(gutterOf(spread(fold: 0.55)), closeTo(0.55, 0.02));
    expect(gutterOf(spread(fold: 0.45)), closeTo(0.45, 0.02));
    // A small picture is looked at as it is.
    expect(gutterOf(spread(width: 200, fold: 0.52)), closeTo(0.52, 0.02));
  });

  test('splits down the middle where there is no shadow', () {
    expect(gutterOf(spread()), 0.5);
  });

  test('splits a spread into its left page and its right page', () {
    final (left, right) = splitSpread(img.encodeJpg(spread(fold: 0.55)));

    final leftPage = img.decodeJpg(left)!;
    final rightPage = img.decodeJpg(right)!;
    expect(leftPage.width + rightPage.width, 400);
    expect(leftPage.width, closeTo(220, 8));
    expect(leftPage.height, 200);
    expect(rightPage.height, 200);
  });
}
