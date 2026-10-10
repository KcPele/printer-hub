import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/tools/tools.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;

  setUp(() => backend = TestBackend());
  tearDown(() => backend.close());

  ExtractTextCubit build() {
    final cubit = ExtractTextCubit(
      picker: backend.picker,
      renderer: backend.renderer,
      reader: backend.textReader,
      sharer: backend.sharer,
      directory: backend.scans,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('starts with nothing chosen', () {
    expect(build().state, const ToolState());
  });

  test('reads every page of a PDF, and leaves no drawn page behind', () async {
    backend.picker.next = pickedPdfFile(backend.scans, name: 'Invoice.pdf');
    final cubit = build();

    await cubit.choose();

    expect(cubit.state.status, ToolStatus.done);
    expect(cubit.state.name, 'Invoice');
    expect(cubit.state.text, 'Invoice 42\nInvoice 42');
    // Two pages were drawn to be read, and are gone again.
    expect(backend.textReader.asked.single, hasLength(2));
    for (final path in backend.textReader.asked.single) {
      expect(File(path).existsSync(), isFalse);
    }
  });

  test('reads a picture as it is', () async {
    final picture = pickedPicture(backend.scans, name: 'Sign.jpg');
    backend.picker.next = picture;
    final cubit = build();

    await cubit.choose();

    expect(cubit.state.text, 'Invoice 42');
    expect(backend.textReader.asked.single, [picture.path]);
    expect(File(picture.path).existsSync(), isTrue);
  });

  test('says when there are no words', () async {
    backend.picker.next = pickedPicture(backend.scans);
    backend.textReader.text = '  ';
    final cubit = build();

    await cubit.choose();

    expect(cubit.state.status, ToolStatus.idle);
    expect(cubit.state.failure, 'tools.no_text');
  });

  test('says when the file cannot be read', () async {
    backend.picker.next = pickedPdfFile(backend.scans);
    backend.renderer.unreadable = true;
    final cubit = build();

    await cubit.choose();

    expect(cubit.state.failure, 'tools.unreadable');

    backend.renderer.unreadable = false;
    backend.textReader.fails = true;
    await cubit.choose();
    expect(cubit.state.failure, 'tools.unreadable');
  });

  test('changes nothing when no file is chosen', () async {
    backend.picker.next = null;
    final cubit = build();

    await cubit.choose();

    expect(cubit.state, const ToolState());
  });

  test('reads one file at a time', () async {
    backend.picker.next = pickedPicture(backend.scans);
    final cubit = build();

    final first = cubit.choose();
    await cubit.choose();
    await first;

    expect(backend.picker.opened, 1);
  });

  test('says nothing once the screen has gone', () async {
    backend.picker.next = pickedPicture(backend.scans);
    final cubit = build();
    final reading = cubit.choose();
    await pumpEventQueue(times: 2);
    await cubit.close();
    await reading;

    final failing = build();
    backend.textReader.fails = true;
    final attempt = failing.choose();
    await pumpEventQueue(times: 2);
    await failing.close();
    await attempt;

    final unchosen = build();
    final choosing = unchosen.choose();
    await unchosen.close();
    await choosing;
    expect(unchosen.state, const ToolState());
  });

  test('shares the words as a text file', () async {
    backend.picker.next = pickedPicture(backend.scans, name: 'Sign.jpg');
    final cubit = build();
    await cubit.share();
    expect(backend.sharer.shared, isEmpty);

    await cubit.choose();
    await cubit.share();

    final shared = backend.sharer.shared.single;
    expect(shared.name, 'Sign');
    expect(shared.files.single.path, endsWith('/Sign.txt'));
    expect(shared.files.single.readAsStringSync(), 'Invoice 42');
  });
}
