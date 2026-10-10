import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:local_store/local_store.dart';
import 'package:printerhub/scan/scan.dart';

void main() {
  const stroke = [Point<double>(40, 30), Point<double>(120, 60)];

  group('signaturePng', () {
    test('draws what was drawn, dark on nothing, cut close to the ink', () {
      final png = signaturePng([stroke], width: 300, height: 150)!;

      final picture = img.decodePng(png)!;
      // Twice the pad's size, and only as large as the ink and its room.
      expect(picture.width, lessThan(300 * 2));
      expect(picture.width, greaterThan(80 * 2));
      expect(picture.height, lessThan(150 * 2));
      var ink = 0;
      var nothing = 0;
      for (final pixel in picture) {
        if (pixel.a > 200 && pixel.r < 60) ink++;
        if (pixel.a == 0) nothing++;
      }
      expect(ink, greaterThan(0));
      expect(nothing, greaterThan(ink));
    });

    test('draws a dot for a tap', () {
      final png = signaturePng(
        [
          [const Point<double>(10, 10)],
        ],
        width: 300,
        height: 150,
      );

      expect(img.decodePng(png!)!.width, greaterThan(1));
    });

    test('is nothing when nothing was drawn', () {
      expect(signaturePng(const [], width: 300, height: 150), isNull);
      expect(signaturePng(const [[]], width: 300, height: 150), isNull);
    });
  });

  test('a signature says how wide it is to its height', () {
    final png = img.encodePng(img.Image(width: 30, height: 10));

    expect(signatureAspect(png), 3);
    expect(signatureAspect(Uint8List.fromList([1, 2, 3])), isNull);
    // The first bytes of a PNG, and then nothing.
    expect(
      signatureAspect(
        Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
      ),
      isNull,
    );
  });

  group('SignatureStore', () {
    test('keeps a signature on the phone, and forgets it when asked', () async {
      final values = InMemorySecureStore();
      final store = SignatureStore(store: values);
      expect(await store.read(), isNull);

      await store.save(Uint8List.fromList([1, 2, 3]));
      expect(await store.read(), [1, 2, 3]);
      expect(values.values.keys, ['signature.png']);

      await store.clear();
      expect(await store.read(), isNull);
    });

    test('has nothing when what is kept cannot be read', () async {
      final store = SignatureStore(
        store: InMemorySecureStore({'signature.png': 'not base64 !!'}),
      );

      expect(await store.read(), isNull);
    });
  });

  test('a placed signature compares by where it is', () {
    final png = Uint8List.fromList([1, 2, 3]);
    PlacedSignature at(double x) =>
        PlacedSignature(png: png, page: 0, x: x, y: 0.5, width: 0.3);

    expect(at(0.2), at(0.2));
    expect(at(0.2), isNot(at(0.3)));
  });
}
