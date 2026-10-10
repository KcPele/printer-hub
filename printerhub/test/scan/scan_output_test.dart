import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:printerhub/scan/scan.dart';
import 'package:printers_repository/printers_repository.dart';

import '../helpers/helpers.dart';

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('scan_output_test');
    addTearDown(() => directory.deleteSync(recursive: true));
  });

  ScannedPage page(String name, {String mimeType = 'image/jpeg'}) {
    final file = File('${directory.path}/$name')..writeAsBytesSync(tinyJpeg);
    return ScannedPage(file: file, mimeType: mimeType);
  }

  String nameOf(File file) => file.uri.pathSegments.last;

  group('assembleScan', () {
    test('makes one PDF of pictures, a page each', () async {
      final files = await assembleScan(
        pages: [page('1.jpg'), page('2.jpg')],
        name: 'Receipts',
        format: 'application/pdf',
        directory: directory,
      );

      expect(files.map(nameOf), ['Receipts.pdf']);
      final written = files.single.readAsBytesSync();
      expect(String.fromCharCodes(written.take(5)), '%PDF-');
      expect(
        RegExp(r'/Type\s*/Page\b').allMatches(String.fromCharCodes(written)),
        hasLength(2),
      );
    });

    test('makes the pages the size that was scanned', () async {
      final files = await assembleScan(
        pages: [page('1.jpg')],
        name: 'Small',
        format: 'application/pdf',
        directory: directory,
        paper: ScanPaper.named('iso_a5_148x210mm'),
      );

      // 148 mm is 419.5 points, and 210 mm is 595.3.
      expect(
        String.fromCharCodes(files.single.readAsBytesSync()),
        matches(RegExp(r'/MediaBox\s*\[\s*0 0 419\.5\d* 595\.2\d*')),
      );
    });

    test('keeps the pictures when no PDF can be made of them', () async {
      final odd = File('${directory.path}/odd.jpg')..writeAsBytesSync(oddJpeg);

      final files = await assembleScan(
        pages: [ScannedPage(file: odd, mimeType: 'image/jpeg')],
        name: 'Odd',
        format: 'application/pdf',
        directory: directory,
      );

      expect(files.map(nameOf), ['Odd.jpg']);
    });

    test('keeps one picture as a picture', () async {
      final files = await assembleScan(
        pages: [page('1.jpg')],
        name: 'Photo',
        format: 'image/jpeg',
        directory: directory,
      );

      expect(files.map(nameOf), ['Photo.jpg']);
      expect(files.single.readAsBytesSync(), tinyJpeg);
    });

    group('of an ID card', () {
      /// What the PDF draws, page by page: the drawing instructions are
      /// stored packed.
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
                // A picture, not instructions.
                return null;
              }
            }(),
        ].where((page) => page.contains(' Do')).toList();
      }

      test('lays the front and the back on one sheet, each the size it '
          'was scanned', () async {
        final files = await assembleScan(
          pages: [page('front.jpg'), page('back.jpg')],
          name: 'Passport card',
          format: 'application/pdf',
          directory: directory,
          card: true,
        );

        expect(files.map(nameOf), ['Passport card.pdf']);
        final sheet = drawn(files.single).single;
        expect(' Do'.allMatches(sheet), hasLength(2));
        // The test picture is square, so it is as tall as the card's
        // area: 60 mm, which is 170.08 points.
        expect(
          RegExp(r'170\.0\d+ 0 0 170\.0\d+').allMatches(sheet),
          hasLength(2),
        );
        // On A4, which is 595.3 points wide.
        expect(
          String.fromCharCodes(files.single.readAsBytesSync()),
          matches(RegExp(r'/MediaBox\s*\[\s*0 0 595\.2\d* 841\.8\d*')),
        );
      });

      test('gives each card a sheet, and a front without its back the '
          'top of one', () async {
        final files = await assembleScan(
          pages: [page('1.jpg'), page('2.jpg'), page('3.jpg')],
          name: 'Cards',
          format: 'application/pdf',
          directory: directory,
          card: true,
        );

        final sheets = drawn(files.single);
        expect(sheets, hasLength(2));
        expect(' Do'.allMatches(sheets.first), hasLength(2));
        expect(' Do'.allMatches(sheets.last), hasLength(1));
      });
    });

    group('with finishing touches', () {
      /// What the PDF draws, page by page.
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
        ].where((page) => page.contains(' Do')).toList();
      }

      test('sets a stamp and a watermark on every page of the PDF', () async {
        final files = await assembleScan(
          pages: [page('1.jpg'), page('2.jpg')],
          name: 'Contract',
          format: 'application/pdf',
          directory: directory,
          finish: const ScanFinish(stamp: 'Oct 10, 2026', watermark: ' COPY '),
        );

        final pages = drawn(files.single);
        expect(pages, hasLength(2));
        for (final words in pages) {
          // The picture, then the two pieces of text over it.
          expect(' Do'.allMatches(words), hasLength(1));
          expect('BT'.allMatches(words).length, greaterThanOrEqualTo(2));
        }
      });

      test('sets nothing on a page when nothing is asked for', () async {
        final files = await assembleScan(
          pages: [page('1.jpg')],
          name: 'Plain',
          format: 'application/pdf',
          directory: directory,
          finish: const ScanFinish(watermark: '   '),
        );

        expect(drawn(files.single).single, isNot(contains('BT')));
      });

      test('sets them on an ID card’s sheet too', () async {
        final files = await assembleScan(
          pages: [page('front.jpg'), page('back.jpg')],
          name: 'Card',
          format: 'application/pdf',
          directory: directory,
          card: true,
          finish: const ScanFinish(watermark: 'COPY'),
        );

        final sheet = drawn(files.single).single;
        expect(' Do'.allMatches(sheet), hasLength(2));
        expect(sheet, contains('BT'));
      });

      test('gives picture pages their look, in a PDF and on their '
          'own', () async {
        final colourful = File('${directory.path}/colour.png')
          ..writeAsBytesSync(
            img.encodePng(
              img.Image(width: 4, height: 4)
                ..clear(img.ColorRgb8(200, 40, 40))
                ..setPixelRgb(0, 0, 250, 250, 250),
            ),
          );
        final scanned = ScannedPage(file: colourful, mimeType: 'image/png');

        final kept = await assembleScan(
          pages: [scanned],
          name: 'Board',
          format: 'image/jpeg',
          directory: directory,
          finish: const ScanFinish(look: ScanLook.blackAndWhite),
        );

        // A look makes a JPEG of the page, whatever it arrived as.
        expect(kept.map(nameOf), ['Board.jpg']);
        final picture = img.decodeJpg(kept.single.readAsBytesSync())!;
        for (final pixel in picture) {
          expect(pixel.r, anyOf(lessThan(40), greaterThan(215)));
        }

        final asPdf = await assembleScan(
          pages: [scanned],
          name: 'Board',
          format: 'application/pdf',
          directory: directory,
          finish: const ScanFinish(look: ScanLook.document),
        );
        expect(asPdf.map(nameOf), ['Board.pdf']);
      });

      test('leaves alone a page it cannot read, and a PDF the scanner '
          'made', () async {
        final odd = File('${directory.path}/odd.jpg')
          ..writeAsBytesSync([1, 2, 3]);

        final files = await assembleScan(
          pages: [
            ScannedPage(file: odd, mimeType: 'image/jpeg'),
            page('made.pdf', mimeType: 'application/pdf'),
          ],
          name: 'Mixed',
          format: 'image/jpeg',
          directory: directory,
          finish: const ScanFinish(look: ScanLook.whiteboard),
        );

        expect(files.map(nameOf), ['Mixed 1.jpg', 'Mixed 2.pdf']);
        expect(files.first.readAsBytesSync(), [1, 2, 3]);
      });
    });

    test('a look changes a picture as it says', () {
      final picture = img.encodePng(
        img.Image(width: 2, height: 2)..clear(img.ColorRgb8(200, 40, 40)),
      );

      for (final look in ScanLook.values) {
        final changed = img.decodeJpg(pictureWithLook(picture, look)!)!;
        final pixel = changed.getPixel(0, 0);
        switch (look) {
          case ScanLook.original:
          case ScanLook.whiteboard:
            expect(pixel.r, greaterThan(pixel.g + 50));
          case ScanLook.document:
          case ScanLook.blackAndWhite:
            // No colour is left.
            expect((pixel.r - pixel.g).abs(), lessThan(12));
        }
      }
      expect(
        pictureWithLook(Uint8List.fromList([9, 9]), ScanLook.document),
        isNull,
      );
    });

    test('finishing touches compare by value, and change one at a '
        'time', () {
      const finish = ScanFinish(stamp: 'today', watermark: 'COPY');

      expect(finish.copyWith(), finish);
      expect(finish.copyWith(look: ScanLook.document).stamp, 'today');
      expect(finish.copyWith(stamp: () => null).stamp, isNull);
      expect(finish.copyWith(watermark: '').watermark, isEmpty);
    });

    test('numbers several pictures', () async {
      final files = await assembleScan(
        pages: [page('1.jpg'), page('2.jpg')],
        name: 'Photo',
        format: 'image/jpeg',
        directory: directory,
      );

      expect(files.map(nameOf), ['Photo 1.jpg', 'Photo 2.jpg']);
    });

    test('keeps the PDFs a scanner made itself as they are', () async {
      final files = await assembleScan(
        pages: [
          page('1.pdf', mimeType: 'application/pdf'),
          page('2.pdf', mimeType: 'application/pdf'),
        ],
        name: 'Contract',
        format: 'application/pdf',
        directory: directory,
      );

      expect(files.map(nameOf), ['Contract 1.pdf', 'Contract 2.pdf']);
    });
  });

  test('a file name has nothing a phone would refuse', () {
    expect(scanFileName('Scan 8/10: "A"'), 'Scan 8-10- -A-');
    expect(scanFileName('  '), 'Scan');
    expect(scanFileName('Minutes'), 'Minutes');
  });

  group('ScanPaper', () {
    test('is found by name, and is A4 when it is not', () {
      expect(ScanPaper.named('na_letter_8.5x11in').widthMm, 215.9);
      expect(ScanPaper.named(null), ScanPaper.a4);
      expect(ScanPaper.named('unknown'), ScanPaper.a4);
    });

    test('fits a scanner that is big enough, or has not said', () {
      const legal = ScanPaper('na_legal_8.5x14in', 215.9, 355.6);

      expect(ScanPaper.a4.fits(216, 297), isTrue);
      // A scanner an A4 sheet fits on says 209.9 by 296.9.
      expect(ScanPaper.a4.fits(209.9, 296.9), isTrue);
      expect(legal.fits(216, 297), isFalse);
      expect(legal.fits(null, null), isTrue);
      expect(legal.fits(0, 0), isTrue);
      expect(ScanPaper.a4.fits(148, 400), isFalse);
    });
  });
}
