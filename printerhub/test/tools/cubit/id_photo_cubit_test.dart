import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:printerhub/pictures/pictures.dart';
import 'package:printerhub/print/print.dart';
import 'package:printerhub/tools/tools.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;
  late KeptFiles kept;

  /// A photo wider than it is tall, as a phone takes one sideways.
  PickedDocument photo({String name = 'Me.jpg'}) {
    final file = File('${backend.scans.path}/$name')
      ..writeAsBytesSync(img.encodeJpg(img.Image(width: 400, height: 300)));
    return PickedDocument.fromFile(file);
  }

  setUp(() {
    backend = TestBackend();
    kept = KeptFiles();
    backend.picker.pictures = [photo()];
  });
  tearDown(() => backend.close());

  IdPhotoCubit build() {
    final cubit = IdPhotoCubit(
      picker: backend.picker,
      sharer: backend.sharer,
      keep: kept.keep,
      name: 'ID photos today',
      directory: backend.scans,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('starts with no photo, at the usual size, on A4', () {
    final state = build().state;
    expect(state, const IdPhotoState());
    expect(state.size.key, '35x45');
    expect(state.copies, 25);
  });

  test('takes a photo and frames it from the middle', () async {
    final cubit = build();

    await cubit.choose();

    final state = cubit.state;
    expect(state.photo!.path, endsWith('/Me.jpg'));
    expect((state.width, state.height), (400, 300));
    expect(state.frame, coverBox(width: 400, height: 300, aspect: 35 / 45));
  });

  test('changes nothing when no photo is chosen, and asks once at a '
      'time', () async {
    backend.picker.pictures = [];
    final cubit = build();
    await cubit.choose();
    expect(cubit.state.photo, isNull);

    backend.picker.pictures = [photo()];
    final first = cubit.choose();
    await cubit.choose();
    await first;
    expect(backend.picker.opened, 2);
  });

  test('says when the photo cannot be read', () async {
    final words = File('${backend.scans.path}/Words.jpg')
      ..writeAsStringSync('not a picture');
    backend.picker.pictures = [PickedDocument.fromFile(words)];
    final cubit = build();

    await cubit.choose();
    expect(cubit.state.failure, 'tools.unreadable');
    expect(cubit.state.photo, isNull);

    // One that has gone from the phone since it was chosen.
    final gone = photo(name: 'Gone.jpg');
    File(gone.path).deleteSync();
    backend.picker.pictures = [gone];
    await cubit.choose();
    expect(cubit.state.failure, 'tools.unreadable');
  });

  test('frames afresh for another size, and keeps where it was moved '
      'to', () async {
    final cubit = build()..setSize(idPhotoSizes[1]);
    // With no photo there is nothing to frame.
    expect(cubit.state.size.key, '51x51');

    await cubit.choose();
    cubit.setSize(idPhotoSizes.first);
    expect(
      cubit.state.frame,
      coverBox(width: 400, height: 300, aspect: 35 / 45),
    );

    const moved = CropBox(left: 0.1, top: 0, right: 0.6, bottom: 0.9);
    cubit
      ..frameTo(moved)
      ..setPaper(photoPapers.last);
    expect(cubit.state.frame, moved);
    expect(cubit.state.paper, photoPapers.last);
  });

  test('makes the sheet, keeps it as ID photos, and shares it', () async {
    final cubit = build();
    // Nothing is made with no photo.
    await cubit.make();
    expect(cubit.state.file, isNull);
    await cubit.share();
    expect(backend.sharer.shared, isEmpty);

    await cubit.choose();
    final making = cubit.make();
    expect(cubit.state.working, isTrue);
    // Nothing changes meanwhile.
    cubit
      ..setSize(idPhotoSizes.last)
      ..setPaper(photoPapers.last)
      ..frameTo(CropBox.start);
    await cubit.choose();
    await cubit.make();
    await making;

    expect(cubit.state.working, isFalse);
    expect(cubit.state.size.key, '35x45');
    expect(cubit.state.file!.path, endsWith('/ID photos today.pdf'));
    expect(kept.kept.single.source, 'id_photo');
    expect(kept.kept.single.mimeType, 'application/pdf');

    await cubit.share();
    expect(backend.sharer.shared.single.name, 'ID photos today');
  });

  test('says when the sheet cannot be made', () async {
    final cubit = build();
    await cubit.choose();
    File(cubit.state.photo!.path).deleteSync();

    await cubit.make();

    expect(cubit.state.failure, 'tools.unreadable');
    expect(cubit.state.working, isFalse);
  });

  test('says nothing once the screen has gone', () async {
    final choosing = IdPhotoCubit(
      picker: backend.picker,
      sharer: backend.sharer,
      keep: kept.keep,
      name: 'a',
      directory: backend.scans,
    );
    final chosen = choosing.choose();
    await choosing.close();
    await chosen;
    expect(choosing.state.photo, isNull);

    final making = IdPhotoCubit(
      picker: backend.picker,
      sharer: backend.sharer,
      keep: kept.keep,
      name: 'b',
      directory: backend.scans,
    );
    await making.choose();
    final made = making.make();
    await making.close();
    await made;
    expect(making.state.file, isNull);

    final failing = IdPhotoCubit(
      picker: backend.picker,
      sharer: backend.sharer,
      keep: kept.keep,
      name: 'c',
      directory: backend.scans,
    );
    await failing.choose();
    File(failing.state.photo!.path).deleteSync();
    final failed = failing.make();
    await failing.close();
    await failed;
    expect(failing.state.failure, isNull);
  });
}
