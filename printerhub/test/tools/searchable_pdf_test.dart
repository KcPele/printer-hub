import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:printerhub/scan/scan.dart';
import 'package:printerhub/tools/tools.dart';

/// What a PDF draws: its packed streams, unpacked.
String unpacked(List<int> pdf) {
  final text = latin1.decode(pdf);
  final drawn = StringBuffer();
  for (final match in RegExp(r'(?<!end)stream\r?\n').allMatches(text)) {
    final end = text.indexOf('endstream', match.end);
    try {
      drawn.write(
        latin1.decode(zlib.decode(pdf.sublist(match.end, end).toList())),
      );
    } on FormatException {
      // A picture's own stream is not packed this way.
    }
  }
  return drawn.toString();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUp(() => directory = Directory.systemTemp.createTempSync('searchable'));
  tearDown(() => directory.deleteSync(recursive: true));

  final page = Uint8List.fromList(
    img.encodeJpg(img.Image(width: 100, height: 140)),
  );

  test('makes a PDF that holds the words read, where they were read', () async {
    final file = await searchablePdf(
      pages: [
        (
          picture: page,
          lines: const [
            TextLine(
              text: 'Invoice 42',
              left: 0.1,
              top: 0.1,
              width: 0.5,
              height: 0.04,
            ),
            // Lines with nothing in them, or no room, are left out.
            TextLine(text: '  ', left: 0, top: 0, width: 1, height: 1),
            TextLine(text: 'Lost', left: 0, top: 0, width: 0, height: 0.1),
          ],
        ),
        (picture: page, lines: const <TextLine>[]),
      ],
      name: 'Invoice searchable',
      directory: directory,
    );

    expect(file.path, endsWith('/Invoice searchable.pdf'));
    final text = latin1.decode(file.readAsBytesSync());
    expect(text, startsWith('%PDF-'));
    expect(RegExp('/Type */Page[^s]').allMatches(text), hasLength(2));
    // The words are set unseen, as text drawn neither filled nor stroked.
    final drawn = unpacked(file.readAsBytesSync());
    expect(drawn, contains('3 Tr'));
    expect(drawn, contains('(Invoice)'));
    expect(drawn, isNot(contains('Lost')));
  });

  test('sets the words in the app’s font where it has one', () async {
    final font = await rootBundle.load(
      'packages/app_ui/assets/fonts/manrope/Manrope.ttf',
    );

    final file = await searchablePdf(
      pages: [
        (
          picture: page,
          lines: const [
            TextLine(
              text: 'Ọjà ńlá',
              left: 0.1,
              top: 0.1,
              width: 0.5,
              height: 0.04,
            ),
          ],
        ),
      ],
      name: 'Words',
      directory: directory,
      font: font,
    );

    expect(latin1.decode(file.readAsBytesSync()), contains('/FontFile2'));
  });

  test('a line read by the phone is read from its answer, and kept inside '
      'the picture', () {
    final line = TextLine.fromMap(const {
      'text': 'Total',
      'left': 0.5,
      'top': -0.1,
      'width': 1.2,
      'height': 0.05,
    });

    expect(
      line,
      const TextLine(text: 'Total', left: 0.5, top: 0, width: 1, height: 0.05),
    );
  });
}
