import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/scan/scan.dart';
import 'package:printerhub/tools/tools.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;
  late KeptFiles kept;

  setUp(() {
    backend = TestBackend();
    kept = KeptFiles();
    backend.picker.pictures = [
      pickedPicture(backend.scans, name: 'One.jpg'),
      pickedPicture(backend.scans, name: 'Two.jpg'),
    ];
  });
  tearDown(() => backend.close());

  PhotoSheetCubit build() {
    final cubit = PhotoSheetCubit(
      picker: backend.picker,
      sharer: backend.sharer,
      keep: kept.keep,
      name: 'Photos today',
      directory: backend.scans,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('starts with no photos, one to a page, on A4', () {
    expect(build().state, const PhotoSheetState());
  });

  test('takes photos, adds more, and lets one be taken out', () async {
    final cubit = build();

    await cubit.choose();
    backend.picker.pictures = [pickedPicture(backend.scans, name: 'Three.jpg')];
    await cubit.choose();
    expect(cubit.state.photos.map((photo) => photo.name), [
      'One.jpg',
      'Two.jpg',
      'Three.jpg',
    ]);

    cubit.remove(cubit.state.photos[1]);
    expect(cubit.state.photos.map((photo) => photo.name), [
      'One.jpg',
      'Three.jpg',
    ]);
  });

  test(
    'changes nothing when none is chosen, and asks once at a time',
    () async {
      backend.picker.pictures = [];
      final cubit = build();

      final first = cubit.choose();
      await cubit.choose();
      await first;

      expect(backend.picker.opened, 1);
      expect(cubit.state.photos, isEmpty);
    },
  );

  test('makes the sheet as asked, and shares it', () async {
    final cubit = build();
    await cubit.make();
    await cubit.share();
    expect(cubit.state.file, isNull);
    expect(backend.sharer.shared, isEmpty);

    await cubit.choose();
    cubit
      ..setLayout(PhotoLayout.two)
      ..setPaper(photoPapers[1]);
    await cubit.make();

    final file = cubit.state.file!;
    expect(file.path, endsWith('/Photos today.pdf'));
    expect(String.fromCharCodes(file.readAsBytesSync().take(5)), '%PDF-');
    expect(cubit.state.working, isFalse);

    await cubit.share();
    expect(backend.sharer.shared.single.files.single.path, file.path);
    // And it was kept without being asked.
    expect(kept.kept.single.file.path, file.path);
    expect(kept.kept.single.mimeType, 'application/pdf');
  });

  test('drops a sheet that is no longer what was asked for', () async {
    final cubit = build();
    await cubit.choose();
    await cubit.make();
    expect(cubit.state.file, isNotNull);

    cubit.setLayout(PhotoLayout.passport);

    expect(cubit.state.file, isNull);
    expect(cubit.state.layout, PhotoLayout.passport);
    expect(cubit.state.paper, ScanPaper.a4);
  });

  test('says when a photo cannot be read', () async {
    final broken = File('${backend.scans.path}/Broken.jpg')
      ..writeAsBytesSync([1, 2, 3]);
    backend.picker.pictures = [
      pickedPicture(backend.scans, name: 'Broken.jpg')..open(),
    ];
    broken.writeAsBytesSync([1, 2, 3]);
    final cubit = build();
    await cubit.choose();

    await cubit.make();

    expect(cubit.state.failure, 'tools.unreadable');
    expect(cubit.state.file, isNull);
  });

  test('changes nothing while the sheet is being made, and says nothing '
      'once the screen has gone', () async {
    final cubit = build();
    await cubit.choose();

    final making = cubit.make();
    cubit
      ..setLayout(PhotoLayout.four)
      ..setPaper(photoPapers.last)
      ..remove(cubit.state.photos.first);
    await cubit.choose();
    await cubit.make();
    await making;
    expect(cubit.state.layout, PhotoLayout.one);
    expect(cubit.state.photos, hasLength(2));

    final gone = build();
    await gone.choose();
    final unfinished = gone.make();
    await gone.close();
    await unfinished;

    final unchosen = build();
    final choosing = unchosen.choose();
    await unchosen.close();
    await choosing;
  });
}
