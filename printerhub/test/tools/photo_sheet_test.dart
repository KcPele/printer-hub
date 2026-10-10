import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:printerhub/scan/scan.dart';
import 'package:printerhub/tools/tools.dart';

import '../helpers/helpers.dart';

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('photo_sheet_test');
    addTearDown(() => directory.deleteSync(recursive: true));
  });

  List<File> photos(int count) => [
    for (var i = 0; i < count; i++)
      File('${directory.path}/photo-$i.jpg')..writeAsBytesSync(tinyJpeg),
  ];

  /// What the PDF draws, sheet by sheet.
  List<String> drawn(File pdf) {
    final bytes = pdf.readAsBytesSync();
    final text = String.fromCharCodes(bytes);
    return [
      for (final stream in RegExp(
        r'(?<!end)stream\r?\n',
      ).allMatches(text).map((start) => start.end))
        ?() {
          try {
            final end = text.indexOf('endstream', stream);
            return String.fromCharCodes(
              zlib.decode(bytes.sublist(stream, end)),
            );
          } on FormatException {
            return null;
          }
        }(),
    ].where((sheet) => sheet.contains(' Do')).toList();
  }

  Future<List<String>> sheets(
    int count,
    PhotoLayout layout, {
    ScanPaper paper = ScanPaper.a4,
  }) async {
    final file = await photoSheet(
      photos: photos(count),
      layout: layout,
      paper: paper,
      name: 'Photos',
      directory: directory,
    );
    expect(file.path, endsWith('/Photos.pdf'));
    return drawn(file);
  }

  int photosOn(String sheet) => ' Do'.allMatches(sheet).length;

  test('puts one photo on each sheet', () async {
    final made = await sheets(3, PhotoLayout.one);

    expect(made.map(photosOn), [1, 1, 1]);
  });

  test('puts two on a sheet, and leaves room on the last', () async {
    final made = await sheets(3, PhotoLayout.two);

    expect(made.map(photosOn), [2, 1]);
  });

  test('puts four on a sheet', () async {
    final made = await sheets(5, PhotoLayout.four);

    expect(made.map(photosOn), [4, 1]);
  });

  test('fills a sheet with passport photos of each picture, at their true '
      'size', () async {
    final made = await sheets(2, PhotoLayout.passport);

    // Five across and five down on A4, a sheet for each picture.
    expect(passportPhotosOn(ScanPaper.a4), 25);
    expect(made.map(photosOn), [25, 25]);
    // 35 mm is 99.21 points and 45 mm is 127.56: each is cut to that box.
    expect((passportWidthMm * PdfPageFormat.mm).toStringAsFixed(2), '99.21');
    expect(made.first, contains(RegExp(r'0 0 99\.21\d* 127\.5\d* re')));
  });

  test('makes the sheet the size of the paper, and fits fewer passport '
      'photos on a small one', () async {
    final small = photoPapers.last;
    final file = await photoSheet(
      photos: photos(1),
      layout: PhotoLayout.passport,
      paper: small,
      name: 'Small',
      directory: directory,
    );

    // 101.6 mm is 288 points, and 152.4 mm is 432.
    expect(
      String.fromCharCodes(file.readAsBytesSync()),
      matches(RegExp(r'/MediaBox\s*\[\s*0 0 288(\.\d+)? 432(\.\d+)?')),
    );
    expect(passportPhotosOn(small), 4);
    expect(photosOn(drawn(file).single), 4);
  });

  test('says when a photo is not a picture', () async {
    final broken = File('${directory.path}/broken.jpg')
      ..writeAsBytesSync([1, 2, 3]);

    await expectLater(
      photoSheet(
        photos: [broken],
        layout: PhotoLayout.one,
        paper: ScanPaper.a4,
        name: 'Broken',
        directory: directory,
      ),
      throwsA(anything),
    );
  });
}
