// Draws the bitmaps of the PrinterHub mark from its SVG: the launcher icons
// for Android versions without adaptive icons, the store icon, and the iOS
// launch image.
//
// It is a test only because drawing needs the Flutter engine, and a test is
// the simplest way to get one from the command line. Run it, with the
// vector forms, through `make app-brand`.
//
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _mint = ui.Color(0xFF46D7B7);

/// The launcher background of each flavor. They match
/// `tool/brand/generate.py`.
const Map<String, ui.Color> _flavors = {
  'main': _mint,
  'development': ui.Color(0xFFFB7746),
  'staging': ui.Color(0xFF4856EB),
};

/// The size of a launcher icon at each screen density, in pixels.
const Map<String, int> _densities = {
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

enum _Shape { square, rounded, circle }

Future<void> _draw({
  required String svg,
  required int size,
  required File to,
  ui.Color? background,
  _Shape shape = _Shape.square,
}) async {
  final picture = await vg.loadPicture(SvgStringLoader(svg), null);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final bounds = ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());

  switch (shape) {
    case _Shape.square:
      break;
    case _Shape.rounded:
      canvas.clipRRect(
        ui.RRect.fromRectAndRadius(bounds, ui.Radius.circular(size * 0.2)),
      );
    case _Shape.circle:
      canvas.clipPath(ui.Path()..addOval(bounds));
  }
  if (background != null) {
    canvas.drawRect(bounds, ui.Paint()..color = background);
  }
  canvas
    ..scale(size / picture.size.width)
    ..drawPicture(picture.picture);

  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  to.parent.createSync(recursive: true);
  to.writeAsBytesSync(bytes!.buffer.asUint8List());
  picture.picture.dispose();
  image.dispose();
  print('drew ${to.path} (${size}px)');
}

void main() {
  testWidgets('draws the bitmaps of the mark', (tester) async {
    await tester.runAsync(() async {
      final mark = File('assets/brand/mark.svg').readAsStringSync();
      final tile = File('assets/brand/tile.svg').readAsStringSync();
      // The app this package belongs to.
      const app = '../..';

      for (final MapEntry(key: flavor, value: background) in _flavors.entries) {
        // On a background that is not mint, mint details become white.
        final onBackground = flavor == 'main'
            ? mark
            : mark.replaceAll('#46D7B7', '#FFFFFF');
        final source = '$app/android/app/src/$flavor';

        for (final MapEntry(key: density, value: size) in _densities.entries) {
          final folder = '$source/res/mipmap-$density';
          await _draw(
            svg: onBackground,
            size: size,
            background: background,
            shape: _Shape.rounded,
            to: File('$folder/ic_launcher.png'),
          );
          await _draw(
            svg: onBackground,
            size: size,
            background: background,
            shape: _Shape.circle,
            to: File('$folder/ic_launcher_round.png'),
          );
        }
        await _draw(
          svg: onBackground,
          size: 512,
          background: background,
          to: File('$source/ic_launcher-playstore.png'),
        );
      }

      const launch = '$app/ios/Runner/Assets.xcassets/LaunchImage.imageset';
      for (final scale in [1, 2, 3]) {
        await _draw(
          svg: tile,
          size: 128 * scale,
          to: File('$launch/LaunchImage@${scale}x.png'),
        );
      }
    });
  });
}
