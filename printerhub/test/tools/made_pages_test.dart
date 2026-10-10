import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/scan/scan.dart';
import 'package:printerhub/tools/tools.dart';

import '../helpers/helpers.dart';

void main() {
  late Directory directory;
  // The font the app sets a PDF's words in.
  final font = ByteData.sublistView(
    File('packages/app_ui/assets/fonts/manrope/Manrope.ttf').readAsBytesSync(),
  );

  setUp(() {
    directory = Directory.systemTemp.createTempSync('made_pages_test');
    addTearDown(() => directory.deleteSync(recursive: true));
  });

  /// What the PDF draws, sheet by sheet: the drawings, and not the
  /// pictures or fonts beside them.
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
    ].where((drawing) => drawing.startsWith('0 Tr')).toList();
  }

  /// How many times a sheet uses a drawing instruction, such as `l` for
  /// a line.
  int count(String sheet, String instruction) =>
      RegExp('(?<=\\s)$instruction(?=\\s)').allMatches(sheet).length;

  /// The size of each sheet, in points, rounded.
  List<(int, int)> sheets(File pdf) => [
    for (final box in RegExp(
      r'/MediaBox\s*\[\s*0 0 ([\d.]+) ([\d.]+)',
    ).allMatches(String.fromCharCodes(pdf.readAsBytesSync())))
      (double.parse(box[1]!).round(), double.parse(box[2]!).round()),
  ];

  group('wifiCode', () {
    test('says how to join a network, with its password', () {
      expect(
        wifiCode(network: 'Office', password: 'let me in'),
        'WIFI:T:WPA;S:Office;P:let me in;;',
      );
    });

    test('says an open network has none', () {
      expect(wifiCode(network: 'Cafe'), 'WIFI:T:nopass;S:Cafe;;');
    });

    test('marks the characters that would end a field', () {
      expect(
        wifiCode(network: r'A;B:C,D"E\F', password: 'x;y'),
        r'WIFI:T:WPA;S:A\;B\:C\,D\"E\\F;P:x\;y;;',
      );
    });

    test('is read back as what was written', () {
      final code = ReadCode.read(
        wifiCode(network: r'A;B:C\D', password: 'p;q:r'),
      );

      expect(code.kind, CodeKind.wifi);
      expect(code.network, r'A;B:C\D');
      expect(code.password, 'p;q:r');
    });
  });

  group('codeSheet', () {
    test('sets a code on one sheet, named as asked', () async {
      final file = await codeSheet(
        data: 'https://example.com',
        paper: ScanPaper.a4,
        name: 'QR code today',
        directory: directory,
      );

      expect(file.path, endsWith('/QR code today.pdf'));
      expect(sheets(file), [(595, 842)]);
      // The code is drawn as many small squares, and no words.
      expect(count(drawn(file).single, 're'), greaterThan(100));
      expect(drawn(file).single, isNot(contains('BT')));
    });

    test('sets a heading above it and words below, in the app’s '
        'font', () async {
      final file = await codeSheet(
        data: 'https://example.com',
        title: ' Café Ñandú ',
        caption: 'example.com',
        paper: sheetPapers.last,
        name: 'Sign',
        directory: directory,
        font: font,
      );

      expect(sheets(file), [(612, 792)]);
      // Each word is set on its own: two in the heading, one below.
      expect(count(drawn(file).single, 'BT'), 3);
    });
  });

  group('noteSheet', () {
    test('sets a note under its heading', () async {
      final file = await noteSheet(
        title: 'Shopping',
        text: 'Milk\nBread\n\nEggs',
        paper: ScanPaper.a4,
        name: 'Note',
        directory: directory,
        font: font,
      );

      expect(sheets(file), hasLength(1));
      expect(drawn(file).single, contains('BT'));
    });

    test('runs a long note on to as many sheets as it takes', () async {
      final file = await noteSheet(
        text: [for (var i = 0; i < 200; i++) 'Line $i of the note'].join('\n'),
        paper: ScanPaper.a4,
        name: 'Long',
        directory: directory,
      );

      expect(sheets(file).length, greaterThan(1));
    });
  });

  group('printableSheet', () {
    Future<File> make(Printable kind, {CalendarMonth? month}) => printableSheet(
      kind: kind,
      paper: ScanPaper.a4,
      name: kind.name,
      directory: directory,
      month: month,
      font: month == null ? null : font,
    );

    test('rules lines across the sheet', () async {
      final sheet = drawn(await make(Printable.lined)).single;

      // 267 mm between the margins, a line every 8 mm.
      expect(count(sheet, 'l'), 33);
    });

    test('rules whole squares', () async {
      final sheet = drawn(await make(Printable.grid)).single;

      // 180 mm across is 36 squares, 267 mm down is 53: a line at each
      // edge of each.
      expect(count(sheet, 'l'), 37 + 54);
    });

    test('sets a dot at each corner of a square', () async {
      final sheet = drawn(await make(Printable.dots)).single;

      // A dot is four curves.
      expect(count(sheet, 'c'), 37 * 54 * 4);
      expect(count(sheet, 'l'), 0);
    });

    test('sets a box to tick on every row', () async {
      final sheet = drawn(await make(Printable.checklist)).single;

      // 267 mm between the margins, a row every 10 mm.
      expect(count(sheet, 're'), greaterThanOrEqualTo(26));
    });

    test('sets a month sideways, a box a day, from the day the week '
        'begins on', () async {
      // October 2026 begins on a Thursday and has 31 days.
      final monday = await make(
        Printable.calendar,
        month: const CalendarMonth(
          year: 2026,
          month: 10,
          title: 'October 2026',
          weekdays: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        ),
      );
      expect(sheets(monday), [(842, 595)]);
      // The title's two words, seven days, and thirty-one numbers.
      expect(count(drawn(monday).single, 'BT'), 2 + 7 + 31);
      // Three boxes before the first, so five weeks.
      expect(count(drawn(monday).single, 're'), 5 * 7);

      // August 2026 begins on a Saturday: with weeks from Monday, its 31
      // days need six of them.
      final august = await make(
        Printable.calendar,
        month: const CalendarMonth(
          year: 2026,
          month: 8,
          title: 'August 2026',
          weekdays: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
          firstWeekday: DateTime.sunday,
        ),
      );
      expect(count(drawn(august).single, 're'), 6 * 7);
    });
  });

  group('pagesOnSheets', () {
    test('sets two pages side by side on a sheet turned sideways', () async {
      final file = await pagesOnSheets(
        pages: [tinyPng, tinyPng, tinyPng],
        perSheet: 2,
        paper: ScanPaper.a4,
        name: 'Two',
        directory: directory,
      );

      expect(sheets(file), [(842, 595), (842, 595)]);
      final text = String.fromCharCodes(file.readAsBytesSync());
      expect(text, contains('/Count 2'));
    });

    test('sets four to an upright sheet', () async {
      final file = await pagesOnSheets(
        pages: [for (var i = 0; i < 5; i++) tinyPng],
        perSheet: 4,
        paper: ScanPaper.a4,
        name: 'Four',
        directory: directory,
      );

      expect(sheets(file), [(595, 842), (595, 842)]);
    });
  });
}
