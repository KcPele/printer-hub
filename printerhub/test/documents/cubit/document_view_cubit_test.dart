import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/documents/documents.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;

  setUp(() => backend = TestBackend());
  tearDown(() => backend.close());

  DocumentViewCubit build(File file, String mimeType) {
    final cubit = DocumentViewCubit(
      renderer: backend.renderer,
      sharer: backend.sharer,
      file: file,
      name: 'Contract.pdf',
      mimeType: mimeType,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  File pdf() => File(pickedPdfFile(backend.scans).path);

  test('starts with nothing drawn', () {
    expect(build(pdf(), 'application/pdf').state, const DocumentViewState());
  });

  test('draws a PDF a page at a time, so the first can be read while the '
      'rest arrive', () async {
    backend.renderer.pageCount = 3;
    final cubit = build(pdf(), 'application/pdf');
    final seen = <(DocumentViewStatus, int)>[];
    final watching = cubit.stream.listen(
      (state) => seen.add((state.status, state.pages.length)),
    );

    await cubit.load();
    await pumpEventQueue();
    await watching.cancel();

    expect(seen, [
      (DocumentViewStatus.loading, 1),
      (DocumentViewStatus.loading, 2),
      (DocumentViewStatus.loading, 3),
      (DocumentViewStatus.ready, 3),
    ]);
  });

  test('shows a picture as it is', () async {
    final picture = File(pickedPicture(backend.scans).path);
    final cubit = build(picture, 'image/jpeg');

    await cubit.load();

    expect(cubit.state.status, DocumentViewStatus.ready);
    expect(cubit.state.pages.single, picture.readAsBytesSync());
  });

  test('says when it cannot show the document', () async {
    // A kind of file the phone does not draw.
    final words = build(pdf(), 'text/plain');
    await words.load();
    expect(words.state.status, DocumentViewStatus.failed);

    // A PDF that cannot be read, and one with no pages.
    backend.renderer.unreadable = true;
    final broken = build(pdf(), 'application/pdf');
    await broken.load();
    expect(broken.state.status, DocumentViewStatus.failed);

    backend.renderer
      ..unreadable = false
      ..pageCount = 0;
    final empty = build(pdf(), 'application/pdf');
    await empty.load();
    expect(empty.state.status, DocumentViewStatus.failed);

    // A picture that is no longer there.
    final gone = build(File('${backend.scans.path}/gone.jpg'), 'image/jpeg');
    await gone.load();
    expect(gone.state.status, DocumentViewStatus.failed);
  });

  test('hands the document to the share sheet', () async {
    final file = pdf();
    final cubit = build(file, 'application/pdf');

    await cubit.share();

    expect(backend.sharer.shared.single.name, 'Contract.pdf');
    expect(backend.sharer.shared.single.files.single.path, file.path);
  });

  test('says nothing once the screen has gone', () async {
    final drawing = build(pdf(), 'application/pdf');
    final loading = drawing.load();
    await drawing.close();
    await loading;

    final picture = build(
      File(pickedPicture(backend.scans).path),
      'image/jpeg',
    );
    final reading = picture.load();
    await picture.close();
    await reading;

    backend.renderer.unreadable = true;
    final broken = build(pdf(), 'application/pdf');
    final failing = broken.load();
    await broken.close();
    await failing;
  });
}
