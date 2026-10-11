import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/documents/documents.dart';
import 'package:printerhub/library/library.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;

  setUp(() => backend = TestBackend());
  tearDown(() => backend.close());

  OpenDocument pdf({String name = 'Contract.pdf'}) => OpenDocument(
    file: File(pickedPdfFile(backend.scans, name: name).path),
    name: name,
    mimeType: 'application/pdf',
  );

  DocumentViewCubit build(OpenDocument document, {KeepFile? keep}) {
    final cubit = DocumentViewCubit(
      renderer: backend.renderer,
      sharer: backend.sharer,
      document: document,
      keep: keep,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('starts with nothing drawn', () {
    final document = pdf();
    expect(build(document).state, DocumentViewState(document: document));
  });

  group('a picture that was changed', () {
    const org = '0198c0de-0000-7000-8000-00000000000b';

    OpenDocument photo() => OpenDocument(
      file: File(pickedPicture(backend.scans).path),
      name: 'Photo.jpg',
      mimeType: 'image/jpeg',
    );

    File changed() =>
        File('${backend.scans.path}/picture-1.jpg')..writeAsBytesSync(tinyJpeg);

    test('is kept as a new document, which is then the one open', () async {
      await backend.signedInBefore();
      final document = photo();
      final cubit = build(document, keep: backend.library.keeper(org));
      await cubit.load();
      expect(cubit.editable, isTrue);

      final kept = await cubit.keepChanged(changed(), name: 'Photo edited');

      expect(kept, isTrue);
      expect(cubit.state.document.name, 'Photo edited.jpg');
      expect(cubit.state.document.file.path, isNot(document.file.path));
      expect(cubit.state.pages.single.path, cubit.state.document.file.path);
      expect(cubit.state.status, DocumentViewStatus.ready);
      // The one it was made from is as it was.
      expect(document.file.existsSync(), isTrue);
      expect(
        backend.library.of(org).map((item) => item.name),
        contains('Photo edited.jpg'),
      );
    });

    test('cannot be kept where there is nowhere to keep it, and only a '
        'picture is changed', () async {
      final cubit = build(photo());
      expect(cubit.editable, isFalse);
      expect(await cubit.keepChanged(changed(), name: 'Photo edited'), isFalse);

      expect(build(pdf(), keep: KeptFiles().keep).editable, isFalse);
    });

    test('says when it could not be kept', () async {
      // The phone has no room for it.
      final full = build(photo(), keep: KeptFiles().keep);
      expect(await full.keepChanged(changed(), name: 'Photo edited'), isFalse);
      expect(full.state.document.name, 'Photo.jpg');

      // The changed picture has gone.
      final gone = build(photo(), keep: KeptFiles().keep);
      expect(
        await gone.keepChanged(
          File('${backend.scans.path}/gone.jpg'),
          name: 'Photo edited',
        ),
        isFalse,
      );
    });

    test('opens nothing once the screen has gone', () async {
      await backend.signedInBefore();
      final cubit = DocumentViewCubit(
        renderer: backend.renderer,
        sharer: backend.sharer,
        document: photo(),
        keep: backend.library.keeper(org),
      );
      final keeping = cubit.keepChanged(changed(), name: 'Photo edited');
      await cubit.close();

      expect(await keeping, isFalse);
    });
  });

  test('draws a PDF a page at a time, so the first can be read while the '
      'rest arrive', () async {
    backend.renderer.pageCount = 3;
    final cubit = build(pdf());
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
    expect(cubit.state.pages.first.readAsBytesSync(), tinyPng);
  });

  test('draws a PDF once: opened again, its pages are there at once, in '
      'order', () async {
    backend.renderer.pageCount = 12;
    final document = pdf();
    await build(document).load();

    // Nothing is drawn the second time.
    backend.renderer.unreadable = true;
    final again = build(document);
    final seen = <DocumentViewStatus>[];
    final watching = again.stream.listen((state) => seen.add(state.status));
    await again.load();
    await pumpEventQueue();
    await watching.cancel();

    expect(seen, [DocumentViewStatus.ready]);
    expect(again.state.pages, hasLength(12));
    expect(again.state.pages[9].path, endsWith('page-00010.png'));
    expect(again.state.pages.last.path, endsWith('page-00012.png'));
  });

  test('draws again a PDF whose drawing was cut short', () async {
    backend.renderer.pageCount = 2;
    final document = pdf();
    // A page from a drawing that never finished.
    Directory('${document.file.path}.pages').createSync();
    File('${document.file.path}.pages/page-00009.png').writeAsBytesSync([1]);

    final cubit = build(document);
    await cubit.load();

    expect(cubit.state.status, DocumentViewStatus.ready);
    expect(cubit.state.pages, hasLength(2));
  });

  test('shows a picture as it is', () async {
    final picture = File(pickedPicture(backend.scans).path);
    final cubit = build(
      OpenDocument(file: picture, name: 'Photo.jpg', mimeType: 'image/jpeg'),
    );

    await cubit.load();

    expect(cubit.state.status, DocumentViewStatus.ready);
    expect(cubit.state.pages.single.path, picture.path);
  });

  test('says when it cannot show the document', () async {
    // A kind of file the phone does not draw.
    final words = build(
      OpenDocument(file: pdf().file, name: 'Notes.txt', mimeType: 'text/plain'),
    );
    await words.load();
    expect(words.state.status, DocumentViewStatus.failed);

    // A PDF that cannot be read, and one with no pages.
    backend.renderer.unreadable = true;
    final broken = build(pdf(name: 'Broken.pdf'));
    await broken.load();
    expect(broken.state.status, DocumentViewStatus.failed);

    backend.renderer
      ..unreadable = false
      ..pageCount = 0;
    final empty = build(pdf(name: 'Empty.pdf'));
    await empty.load();
    expect(empty.state.status, DocumentViewStatus.failed);

    // A picture that is no longer there.
    final gone = build(
      OpenDocument(
        file: File('${backend.scans.path}/gone.jpg'),
        name: 'gone.jpg',
        mimeType: 'image/jpeg',
      ),
    );
    await gone.load();
    expect(gone.state.status, DocumentViewStatus.failed);
  });

  test('hands the document to the share sheet', () async {
    final document = pdf();
    final cubit = build(document);

    await cubit.share();

    expect(backend.sharer.shared.single.name, 'Contract.pdf');
    expect(backend.sharer.shared.single.files.single.path, document.file.path);
  });

  test('says nothing once the screen has gone', () async {
    final drawing = build(pdf());
    final loading = drawing.load();
    await drawing.close();
    await loading;

    // Gone between the last page and the end.
    backend.renderer.pageCount = 1;
    final finishing = build(pdf(name: 'Other.pdf'));
    final ending = finishing.load();
    await finishing.stream.first;
    await finishing.close();
    await ending;

    backend.renderer.unreadable = true;
    final broken = build(pdf(name: 'Broken.pdf'));
    final failing = broken.load();
    await broken.close();
    await failing;
  });

  test('an open document knows its kind, and goes to a tool as a file', () {
    final document = pdf();
    final picture = OpenDocument(
      file: File('${backend.scans.path}/gone.jpg'),
      name: 'gone.jpg',
      mimeType: 'image/jpeg',
    );

    expect((document.isPdf, document.isPicture), (true, false));
    expect((picture.isPdf, picture.isPicture), (false, true));
    expect(document.picked.name, 'Contract.pdf');
    expect(document.picked.path, document.file.path);
    expect(document.picked.length, greaterThan(0));
    expect(document.picked.mimeType, 'application/pdf');
    // A file that has gone has no size to speak of.
    expect(picture.picked.length, 0);
    expect(document, pdf());
    expect(document, isNot(picture));
  });
}
