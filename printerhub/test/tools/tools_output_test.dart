import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:printerhub/tools/tools.dart';

import '../helpers/helpers.dart';

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('tools_output_test');
    addTearDown(() => directory.deleteSync(recursive: true));
  });

  String nameOf(File file) => file.uri.pathSegments.last;

  /// A PNG of one colour, [width] by [height].
  Uint8List png(int width, int height) =>
      img.encodePng(img.Image(width: width, height: height));

  group('pagesAsPictures', () {
    test('writes a JPEG a page, numbered', () async {
      final files = await pagesAsPictures(
        pages: [tinyPng, tinyPng],
        name: 'Report',
        directory: directory,
      );

      expect(files.map(nameOf), ['Report 1.jpg', 'Report 2.jpg']);
      for (final file in files) {
        // Every JPEG begins with these two bytes.
        expect(file.readAsBytesSync().take(2), [0xFF, 0xD8]);
      }
    });

    test('does not number one page', () async {
      final files = await pagesAsPictures(
        pages: [tinyPng],
        name: 'One: page',
        directory: directory,
      );

      expect(files.map(nameOf), ['One- page.jpg']);
    });

    test('says when a page is not a picture', () async {
      await expectLater(
        pagesAsPictures(
          pages: [
            Uint8List.fromList([1, 2, 3]),
          ],
          name: 'Broken',
          directory: directory,
        ),
        throwsA(isA<UnreadablePage>()),
      );
    });
  });

  group('pagesAsLongPicture', () {
    test('joins the pages top to bottom, as wide as the narrowest', () async {
      final file = await pagesAsLongPicture(
        pages: [png(40, 30), png(20, 10), png(20, 5)],
        name: 'Thread',
        directory: directory,
      );

      expect(nameOf(file), 'Thread.jpg');
      final long = img.decodeJpg(file.readAsBytesSync())!;
      expect(long.width, 20);
      // The wide page is halved to fit: 15, then 10, then 5.
      expect(long.height, 30);
    });
  });

  test('textAsFile writes the words as they are', () async {
    final file = await textAsFile(
      text: 'Invoice 42\nTotal due',
      name: 'Invoice',
      directory: directory,
    );

    expect(nameOf(file), 'Invoice.txt');
    expect(file.readAsStringSync(), 'Invoice 42\nTotal due');
  });

  test('a name loses its ending, and only its ending', () {
    expect(nameWithoutEnding('Report.pdf'), 'Report');
    expect(nameWithoutEnding('Q3.report.final.pdf'), 'Q3.report.final');
    expect(nameWithoutEnding('Notes'), 'Notes');
    expect(nameWithoutEnding('.hidden'), '.hidden');
  });
}
