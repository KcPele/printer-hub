import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/tools/tools.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;
  late KeptFiles kept;

  setUp(() {
    backend = TestBackend();
    kept = KeptFiles();
  });
  tearDown(() => backend.close());

  Future<ByteData?> noFont() async => null;

  SearchableCubit build() {
    final cubit = SearchableCubit(
      picker: backend.picker,
      renderer: backend.renderer,
      reader: backend.textReader,
      sharer: backend.sharer,
      keep: kept.keep,
      font: noFont,
      directory: backend.scans,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('starts with nothing chosen', () {
    expect(build().state, const ToolState());
  });

  test('makes a PDF of each page with its words, keeps it, and leaves no '
      'drawn page behind', () async {
    backend.picker.next = pickedPdfFile(backend.scans, name: 'Invoice.pdf');
    final cubit = build();

    await cubit.choose();

    expect(cubit.state.status, ToolStatus.done);
    expect(cubit.state.name, 'Invoice searchable');
    final file = cubit.state.files.single;
    expect(file.path, endsWith('/Invoice searchable.pdf'));
    expect(kept.kept.single.source, 'searchable_pdf');
    expect(kept.kept.single.pageCount, 2);
    // Each page was read on its own, and the drawings of them are gone.
    expect(backend.textReader.asked, hasLength(2));
    for (final [path] in backend.textReader.asked) {
      expect(File(path).existsSync(), isFalse);
    }

    await cubit.share();
    expect(backend.sharer.shared.single.files.single.path, file.path);
  });

  test('reads a picture as it is, and one already open, one at a '
      'time', () async {
    final picture = pickedPicture(backend.scans, name: 'Receipt.jpg');
    final cubit = build();

    final first = cubit.start(picture);
    await cubit.start(picture);
    await first;

    expect(cubit.state.status, ToolStatus.done);
    expect(backend.textReader.asked.single.single, picture.path);
    expect(backend.picker.opened, 0);
  });

  test('says when there are no words to find, or none can be read', () async {
    backend.picker.next = pickedPicture(backend.scans);
    backend.textReader.pageLines = const [];
    final empty = build();
    await empty.choose();
    expect(empty.state.failure, 'tools.no_text');
    expect(kept.kept, isEmpty);

    backend.textReader.fails = true;
    final failing = build();
    await failing.choose();
    expect(failing.state.failure, 'tools.unreadable');

    // Nothing is shared before something is made, and nothing chosen is
    // nothing done.
    await failing.share();
    expect(backend.sharer.shared, isEmpty);
    backend.picker.next = null;
    final none = build();
    await none.choose();
    expect(none.state, const ToolState());
  });

  test('says nothing once the screen has gone', () async {
    backend.picker.next = pickedPicture(backend.scans);
    final cubit = build();
    final working = cubit.choose();
    await cubit.close();
    await working;
    expect(cubit.state.status, ToolStatus.idle);

    backend.textReader.fails = true;
    final failing = build();
    final failed = failing.choose();
    await failing.close();
    await failed;
    expect(failing.state.failure, isNull);
  });

  test('says nothing once the screen has gone while the PDF is made', () async {
    backend.picker.next = pickedPicture(backend.scans);
    late SearchableCubit cubit;
    cubit = SearchableCubit(
      picker: backend.picker,
      renderer: backend.renderer,
      reader: backend.textReader,
      sharer: backend.sharer,
      keep: kept.keep,
      // The screen goes while the font is fetched.
      font: () async {
        await cubit.close();
        return null;
      },
      directory: backend.scans,
    );

    await cubit.choose();

    expect(cubit.state.status, ToolStatus.working);
    expect(kept.kept, hasLength(1));
  });
}
