import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:printerhub/scan/scan.dart';
import 'package:printerhub/tools/tools.dart';

void main() {
  late Directory directory;

  setUp(() => directory = Directory.systemTemp.createTempSync('id_photo'));
  tearDown(() => directory.deleteSync(recursive: true));

  test('offers the sizes offices ask for, the usual one first', () {
    expect(idPhotoSizes.first, const IdPhotoSize('35x45', 35, 45));
    expect(idPhotoSizes.first.aspect, closeTo(35 / 45, 1e-9));
    expect(idPhotoSizes.map((size) => size.key), [
      '35x45',
      '51x51',
      '33x48',
      '50x70',
    ]);
  });

  test('frames as much of a photo as fits, from the middle', () {
    // A wide photo loses its sides.
    final wide = coverBox(width: 400, height: 200, aspect: 1);
    expect(wide.left, closeTo(0.25, 1e-9));
    expect(wide.right, closeTo(0.75, 1e-9));
    expect((wide.top, wide.bottom), (0, 1));

    // A tall one loses its top and bottom.
    final tall = coverBox(width: 200, height: 400, aspect: 1);
    expect(tall.top, closeTo(0.25, 1e-9));
    expect(tall.bottom, closeTo(0.75, 1e-9));
    expect((tall.left, tall.right), (0, 1));
  });

  test('fits as many photos on a sheet as there is room for', () {
    expect(photosFitOn(ScanPaper.a4, widthMm: 35, heightMm: 45), 25);
    expect(photosFitOn(ScanPaper.a4, widthMm: 50, heightMm: 70), 9);
    expect(passportPhotosOn(ScanPaper.a4), 25);
    // Nothing that size fits at all.
    expect(photosFitOn(ScanPaper.a4, widthMm: 500, heightMm: 500), 0);
  });

  test('makes a sheet of copies as a PDF', () async {
    final photo = img.encodeJpg(img.Image(width: 70, height: 90));

    final sheet = await idPhotoSheet(
      photo: photo,
      size: idPhotoSizes.first,
      paper: ScanPaper.a4,
      name: 'ID photos today',
      directory: directory,
    );

    expect(sheet.path, endsWith('/ID photos today.pdf'));
    expect(String.fromCharCodes(sheet.readAsBytesSync().take(5)), '%PDF-');
  });
}
