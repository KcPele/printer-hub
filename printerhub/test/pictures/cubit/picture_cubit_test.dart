import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:printerhub/pictures/pictures.dart';

import '../picture_edits_test.dart' show grey;

void main() {
  late Directory directory;
  late File picture;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('picture_cubit');
    picture = File('${directory.path}/photo.jpg')..writeAsBytesSync(grey());
  });
  tearDown(() => directory.deleteSync(recursive: true));

  PictureCubit build([File? file]) {
    final cubit = PictureCubit(picture: file ?? picture, directory: directory);
    addTearDown(cubit.close);
    return cubit;
  }

  Future<PictureCubit> loaded() async {
    final cubit = build();
    await cubit.load();
    return cubit;
  }

  (int, int) sizeOf(File file) {
    final decoded = img.decodeJpg(file.readAsBytesSync())!;
    return (decoded.width, decoded.height);
  }

  test('starts with the picture, not yet read', () {
    final cubit = build();
    expect(cubit.state, PictureState(file: picture));
    expect(cubit.state.ready, isFalse);
  });

  test('reads how large the picture is', () async {
    final cubit = await loaded();

    expect(cubit.state.ready, isTrue);
    expect((cubit.state.width, cubit.state.height), (40, 20));
    expect(cubit.state.changed, isFalse);
  });

  test('says when the picture cannot be read', () async {
    final words = build(
      File('${directory.path}/words.jpg')..writeAsStringSync('not a picture'),
    );
    await words.load();
    expect(words.state.failed, isTrue);
    expect(words.state.ready, isFalse);

    final gone = build(File('${directory.path}/gone.jpg'));
    await gone.load();
    expect(gone.state.failed, isTrue);
  });

  test('does nothing to a picture that has not been read', () async {
    final cubit = build()..choose(PictureTool.crop);
    await cubit.turn();

    expect(cubit.state, PictureState(file: picture));
  });

  test('crops to the box, as a new picture, and takes it back', () async {
    final cubit = await loaded()
      ..choose(PictureTool.crop)
      ..cropTo(const CropBox(left: 0, top: 0, right: 0.5, bottom: 0.5));
    expect(cubit.state.tool, PictureTool.crop);

    await cubit.apply();

    expect(cubit.state.tool, PictureTool.none);
    expect(cubit.state.changed, isTrue);
    expect(cubit.state.file.path, isNot(picture.path));
    expect((cubit.state.width, cubit.state.height), (20, 10));
    expect(sizeOf(cubit.state.file), (20, 10));
    // The picture it was opened on is as it was.
    expect(sizeOf(picture), (40, 20));

    cubit.undo();
    expect(cubit.state.file.path, picture.path);
    expect((cubit.state.width, cubit.state.height), (40, 20));
    expect(cubit.state.changed, isFalse);

    // With nothing left to take back, nothing happens.
    cubit.undo();
    expect(cubit.state.file.path, picture.path);
  });

  test('puts a tool down without using it', () async {
    final cubit = await loaded()
      ..choose(PictureTool.crop)
      ..cropTo(CropBox.start.moved(left: 0.2))
      ..choose(PictureTool.none);

    expect(cubit.state.tool, PictureTool.none);
    expect(cubit.state.changed, isFalse);
    // Taken up again, the box begins afresh.
    cubit.choose(PictureTool.crop);
    expect(cubit.state.crop, CropBox.start);
  });

  test('draws highlighter lines, kept inside the picture, and marks the '
      'picture with them', () async {
    final cubit = await loaded()
      // Before a line is begun, there is nothing to carry on.
      ..choose(PictureTool.highlight)
      ..drawTo(const Point(0.5, 0.5));
    expect(cubit.state.strokes, isEmpty);

    cubit
      ..begin(const Point(0.2, 0.5))
      ..drawTo(const Point(0.8, 0.5))
      ..begin(const Point(-1, 2));
    expect(cubit.state.strokes, const [
      PictureStroke(points: [Point(0.2, 0.5), Point(0.8, 0.5)]),
      PictureStroke(points: [Point(0, 1)]),
    ]);

    await cubit.apply();

    expect(cubit.state.tool, PictureTool.none);
    expect(cubit.state.strokes, isEmpty);
    expect(cubit.state.changed, isTrue);
    final marked = img.decodeJpg(cubit.state.file.readAsBytesSync())!;
    expect(marked.getPixel(20, 10).b, lessThan(110));
  });

  test('draws each line with the highlighter in hand', () async {
    final cubit = await loaded()
      // With no highlighter taken up, there is none to choose.
      ..pick(color: HighlightColor.pink);
    expect(cubit.state.color, HighlightColor.yellow);
    expect(cubit.state.pen, HighlightPen.thick);

    cubit
      ..choose(PictureTool.highlight)
      ..begin(const Point(0.1, 0.1))
      ..pick(color: HighlightColor.blue)
      ..pick(pen: HighlightPen.thin)
      ..begin(const Point(0.5, 0.5));

    expect(cubit.state.color, HighlightColor.blue);
    expect(cubit.state.pen, HighlightPen.thin);
    // The line already drawn keeps its own.
    expect(cubit.state.strokes, const [
      PictureStroke(points: [Point(0.1, 0.1)]),
      PictureStroke(
        points: [Point(0.5, 0.5)],
        color: HighlightColor.blue,
        pen: HighlightPen.thin,
      ),
    ]);
  });

  test('changes nothing when no line was drawn', () async {
    final cubit = await loaded()
      ..choose(PictureTool.highlight);

    await cubit.apply();

    expect(cubit.state.tool, PictureTool.none);
    expect(cubit.state.changed, isFalse);
  });

  test('turns the picture, and again', () async {
    final cubit = await loaded();

    await cubit.turn();
    expect((cubit.state.width, cubit.state.height), (20, 40));
    await cubit.turn();
    expect((cubit.state.width, cubit.state.height), (40, 20));

    cubit.undo();
    expect((cubit.state.width, cubit.state.height), (20, 40));
    expect(cubit.state.changed, isTrue);
  });

  test('a tool does only its own work', () async {
    final cubit = await loaded();

    // With no tool in hand.
    await cubit.apply();
    cubit
      ..cropTo(CropBox.start.moved(left: 0.2))
      ..begin(const Point(0.5, 0.5))
      ..drawTo(const Point(0.6, 0.5));
    expect(cubit.state.crop, CropBox.start);
    expect(cubit.state.strokes, isEmpty);

    // With one in hand, the picture is not turned.
    cubit.choose(PictureTool.crop);
    await cubit.turn();
    expect(cubit.state.changed, isFalse);
    expect(cubit.state.tool, PictureTool.crop);
  });

  test('does one thing at a time', () async {
    final cubit = await loaded();

    final turning = cubit.turn();
    expect(cubit.state.working, isTrue);
    cubit
      ..choose(PictureTool.highlight)
      ..cropTo(CropBox.start.moved(left: 0.2))
      ..begin(const Point(0.5, 0.5))
      ..drawTo(const Point(0.6, 0.5))
      ..pick(pen: HighlightPen.thin)
      ..undo();
    await cubit.turn();
    await turning;

    expect(cubit.state.working, isFalse);
    expect(cubit.state.tool, PictureTool.none);
    expect((cubit.state.width, cubit.state.height), (20, 40));
  });

  test('says when a change could not be made, and keeps the picture', () async {
    final cubit = await loaded();
    picture.deleteSync();

    await cubit.turn();

    expect(cubit.state.failed, isTrue);
    expect(cubit.state.working, isFalse);
    expect(cubit.state.changed, isFalse);
    expect(cubit.state.ready, isTrue);
  });

  test('says nothing once the screen has gone', () async {
    final reading = PictureCubit(picture: picture, directory: directory);
    final read = reading.load();
    await reading.close();
    await read;
    expect(reading.state.ready, isFalse);

    final unreadable = PictureCubit(
      picture: File('${directory.path}/gone.jpg'),
      directory: directory,
    );
    final failing = unreadable.load();
    await unreadable.close();
    await failing;
    expect(unreadable.state.failed, isFalse);

    final turned = PictureCubit(picture: picture, directory: directory);
    await turned.load();
    final turning = turned.turn();
    await turned.close();
    await turning;
    expect(turned.state.changed, isFalse);

    final broken = PictureCubit(picture: picture, directory: directory);
    await broken.load();
    picture.deleteSync();
    final breaking = broken.turn();
    await broken.close();
    await breaking;
    expect(broken.state.failed, isFalse);
  });
}
