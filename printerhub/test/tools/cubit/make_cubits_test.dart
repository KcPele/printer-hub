import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/tools/tools.dart';

import '../../helpers/helpers.dart';

void main() {
  late Directory directory;
  late FakeScanSharer sharer;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('make_cubits_test');
    addTearDown(() => directory.deleteSync(recursive: true));
    sharer = FakeScanSharer();
  });

  Future<ByteData?> noFont() async => null;

  group('CodeSheetCubit', () {
    CodeSheetCubit build({PdfFontLoader? font}) {
      final cubit = CodeSheetCubit(
        sharer: sharer,
        name: 'QR code today',
        font: font ?? noFont,
        directory: directory,
      );
      addTearDown(cubit.close);
      return cubit;
    }

    test('makes nothing until there is something for the code to '
        'say', () async {
      final cubit = build();
      expect(cubit.ready(cubit.state.choices), isFalse);

      await cubit.make();
      await cubit.share();

      expect(cubit.state.file, isNull);
      expect(sharer.shared, isEmpty);
    });

    test('makes a sign for a link, and shares it', () async {
      final cubit = build()
        ..change(const CodeSheetChoices(text: ' https://example.com '));
      expect(cubit.ready(cubit.state.choices), isTrue);

      final making = cubit.make();
      expect(cubit.state.working, isTrue);
      // Nothing changes, and nothing is made twice, while it is made.
      cubit.change(const CodeSheetChoices(text: 'other'));
      await cubit.make();
      await making;

      expect(cubit.state.working, isFalse);
      expect(cubit.state.choices.text, ' https://example.com ');
      expect(cubit.state.file!.path, endsWith('/QR code today.pdf'));

      await cubit.share();
      expect(sharer.shared.single.name, 'QR code today');
      expect(sharer.shared.single.files.single.path, cubit.state.file!.path);
    });

    test('drops the sign when what it says changes', () async {
      final cubit = build()..change(const CodeSheetChoices(text: 'Hello'));
      await cubit.make();

      cubit.change(cubit.state.choices.copyWith(title: 'Welcome'));

      expect(cubit.state.file, isNull);
      expect(cubit.state.choices.text, 'Hello');
    });

    test('makes a sign for a Wi-Fi network, which needs only its '
        'name', () async {
      final cubit = build()..change(const CodeSheetChoices(wifi: true));
      expect(cubit.ready(cubit.state.choices), isFalse);

      cubit.change(
        cubit.state.choices.copyWith(network: 'Office', password: 'secret'),
      );
      await cubit.make();

      expect(cubit.state.file, isNotNull);
    });

    test('leaves words too long to read off the sign', () async {
      final cubit = build()..change(CodeSheetChoices(text: 'long ' * 40));

      await cubit.make();

      expect(cubit.state.file, isNotNull);
    });

    test('says when the sign could not be made', () async {
      final cubit = build(font: () => throw const FormatException('bad'))
        ..change(const CodeSheetChoices(text: 'Hello'));

      await cubit.make();

      expect(cubit.state.failure, 'tools.unreadable');
      expect(cubit.state.file, isNull);
    });

    test('says nothing once the screen has gone', () async {
      final made = build()..change(const CodeSheetChoices(text: 'Hello'));
      final making = made.make();
      await made.close();
      await making;

      final failed = build(font: () => throw const FormatException('bad'))
        ..change(const CodeSheetChoices(text: 'Hello'));
      final failing = failed.make();
      await failed.close();
      await failing;
    });

    test('choices change one at a time, and compare by value', () {
      const choices = CodeSheetChoices(text: 'a', title: 't');

      expect(choices.copyWith(), choices);
      expect(choices.copyWith(text: 'b').title, 't');
      expect(choices.copyWith(paper: sheetPapers.last), isNot(choices));
      expect(choices.copyWith(wifi: true).wifi, isTrue);
    });
  });

  group('NoteCubit', () {
    NoteCubit build() {
      final cubit = NoteCubit(
        sharer: sharer,
        name: 'Note today',
        font: noFont,
        directory: directory,
      );
      addTearDown(cubit.close);
      return cubit;
    }

    test('needs words to print', () async {
      final cubit = build()..change(const NoteChoices(title: 'List'));

      await cubit.make();

      expect(cubit.ready(cubit.state.choices), isFalse);
      expect(cubit.state.file, isNull);
    });

    test('makes a document of what was typed', () async {
      final cubit = build()
        ..change(const NoteChoices(title: 'List', text: 'Milk\nBread'));

      await cubit.make();

      expect(cubit.state.file!.path, endsWith('/Note today.pdf'));
    });

    test('choices change one at a time, and compare by value', () {
      const choices = NoteChoices(title: 't', text: 'x');

      expect(choices.copyWith(), choices);
      expect(choices.copyWith(text: 'y').title, 't');
      expect(choices.copyWith(title: 'u').text, 'x');
      expect(choices.copyWith(paper: sheetPapers.last), isNot(choices));
    });
  });

  group('PrintableCubit', () {
    late List<(int, int)> asked;
    late int fonts;

    PrintableCubit build() {
      asked = [];
      fonts = 0;
      final cubit = PrintableCubit(
        sharer: sharer,
        name: 'Page today',
        today: DateTime(2026, 10, 10),
        calendar: (year, month) {
          asked.add((year, month));
          return CalendarMonth(
            year: year,
            month: month,
            title: '$month/$year',
            weekdays: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
          );
        },
        font: () async {
          fonts++;
          return null;
        },
        directory: directory,
      );
      addTearDown(cubit.close);
      return cubit;
    }

    test('makes lined paper as it stands, with no words to set', () async {
      final cubit = build();

      await cubit.make();

      expect(cubit.state.file!.path, endsWith('/Page today.pdf'));
      expect(asked, isEmpty);
      expect(fonts, 0);
    });

    test('makes this month’s calendar, or another month’s', () async {
      final cubit = build();
      cubit.change(cubit.state.choices.copyWith(kind: Printable.calendar));
      await cubit.make();
      expect(asked, [(2026, 10)]);
      expect(fonts, 1);

      cubit.change(cubit.state.choices.later(3));
      expect(cubit.state.choices.kind, Printable.calendar);
      await cubit.make();
      cubit.change(cubit.state.choices.later(-4));
      await cubit.make();

      expect(asked, [(2026, 10), (2027, 1), (2026, 9)]);
    });

    test('choices change one at a time, and compare by value', () {
      const choices = PrintableChoices(year: 2026, month: 10);

      expect(choices.copyWith(), choices);
      expect(choices.copyWith(kind: Printable.grid).month, 10);
      expect(choices.copyWith(paper: sheetPapers.last), isNot(choices));
    });
  });

  group('PagesPerSheetCubit', () {
    late FakeDocumentPicker picker;
    late FakePageRenderer renderer;

    PagesPerSheetCubit build() {
      picker = FakeDocumentPicker();
      renderer = FakePageRenderer()..pageCount = 5;
      final cubit = PagesPerSheetCubit(
        sharer: sharer,
        name: 'Pages today',
        picker: picker,
        renderer: renderer,
        directory: directory,
      );
      addTearDown(cubit.close);
      return cubit;
    }

    test('needs a PDF before it makes anything', () async {
      final cubit = build();
      picker.next = null;

      await cubit.choose();
      await cubit.make();

      expect(cubit.ready(cubit.state.choices), isFalse);
      expect(cubit.state.file, isNull);
    });

    test('sets a PDF’s pages several to a sheet', () async {
      final cubit = build();

      await cubit.choose();
      expect(cubit.state.choices.document!.name, 'Report.pdf');
      cubit.change(cubit.state.choices.copyWith(perSheet: 4));
      await cubit.make();

      final file = cubit.state.file!;
      expect(file.path, endsWith('/Pages today.pdf'));
      // Five pages, four to a sheet.
      expect(
        String.fromCharCodes(file.readAsBytesSync()),
        contains('/Count 2'),
      );
    });

    test('says when the PDF cannot be read', () async {
      final cubit = build();
      renderer.unreadable = true;

      await cubit.choose();
      await cubit.make();

      expect(cubit.state.failure, 'tools.unreadable');
    });

    test('asks for one file at a time, and says nothing once the screen '
        'has gone', () async {
      final cubit = build();
      final first = cubit.choose();
      await cubit.choose();
      await first;
      expect(picker.opened, 1);

      final closing = cubit.choose();
      await cubit.close();
      await closing;
    });

    test('choices change one at a time, and compare by value', () {
      const choices = PagesPerSheetChoices();

      expect(choices.copyWith(), choices);
      expect(choices.copyWith(perSheet: 4).document, isNull);
      expect(choices.copyWith(paper: sheetPapers.last), isNot(choices));
      expect(choices.copyWith(document: pickedPdf()).document, isNotNull);
    });
  });

  group('CodeCubit', () {
    late FakeLinkOpener links;

    CodeCubit build() {
      links = FakeLinkOpener();
      final cubit = CodeCubit(links: links);
      addTearDown(cubit.close);
      return cubit;
    }

    test('keeps the first code the camera reads', () {
      final cubit = build()
        ..found('  ')
        ..found('https://example.com')
        ..found('something else');

      expect(cubit.state.code!.text, 'https://example.com');
    });

    test('opens a link, and says when nothing would', () async {
      final cubit = build()..found('https://example.com');

      await cubit.open();
      expect(links.opened, [Uri.parse('https://example.com')]);
      expect(cubit.state.unopened, isFalse);

      links.opens = false;
      await cubit.open();
      expect(cubit.state.unopened, isTrue);
      expect(cubit.state.code, isNotNull);
    });

    test('opens nothing for words, or before a code is read', () async {
      final cubit = build();
      await cubit.open();
      cubit.found('just words');
      await cubit.open();

      expect(links.opened, isEmpty);
    });

    test('goes back for another, and says nothing once the screen has '
        'gone', () async {
      final cubit = build()
        ..found('https://example.com')
        ..again();
      expect(cubit.state, const CodeState());

      cubit.found('https://example.com');
      final opening = cubit.open();
      await cubit.close();
      await opening;
    });
  });
}
