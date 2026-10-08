import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
