import 'dart:io';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/pictures/pictures.dart';

import '../../helpers/helpers.dart';
import '../picture_edits_test.dart' show grey;

void main() {
  late Directory directory;
  late File picture;
  late PictureCubit cubit;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('picture_view');
    picture = File('${directory.path}/photo.jpg')..writeAsBytesSync(grey());
    cubit = PictureCubit(picture: picture, directory: directory);
  });
  tearDown(() async {
    await cubit.close();
    directory.deleteSync(recursive: true);
  });

  PictureState ready({
    PictureTool tool = PictureTool.none,
    bool working = false,
    bool failed = false,
    bool changed = false,
    List<PictureStroke> strokes = const [],
  }) => PictureState(
    file: picture,
    width: 40,
    height: 20,
    tool: tool,
    working: working,
    failed: failed,
    changed: changed,
    strokes: strokes,
  );

  Future<void> pump(
    WidgetTester tester, {
    PictureState? state,
    bool editable = true,
  }) async {
    if (state != null) cubit.emit(state);
    await tester.pumpApp(
      BlocProvider.value(
        value: cubit,
        child: PictureViewView(editable: editable),
      ),
    );
  }

  testWidgets('waits while the picture is read', (tester) async {
    await pump(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Crop'), findsNothing);
  });

  testWidgets('says when the picture cannot be shown', (tester) async {
    await pump(tester, state: PictureState(file: picture, failed: true));

    expect(find.text('This picture cannot be shown.'), findsOneWidget);
    expect(find.text('Crop'), findsNothing);
  });

  testWidgets('shows the picture to pinch larger, with its tools below', (
    tester,
  ) async {
    await pump(tester, state: ready());

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Crop'), findsOneWidget);
    expect(find.text('Highlight'), findsOneWidget);
    expect(find.text('Turn'), findsOneWidget);
    // Nothing to save or take back yet.
    expect(find.text('Save'), findsNothing);
    expect(find.byTooltip('Undo'), findsNothing);
  });

  testWidgets('only shows a picture that cannot be changed', (tester) async {
    await pump(tester, state: ready(), editable: false);

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Crop'), findsNothing);
  });

  testWidgets('crops: the box is sized by its corners and moved by its '
      'middle', (tester) async {
    await pump(tester, state: ready());

    await tester.tap(find.text('Crop'));
    await tester.pump();
    expect(cubit.state.tool, PictureTool.crop);
    // It keeps still while it is worked on.
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.text('Apply'), findsOneWidget);

    for (final (corner, by) in [
      ('top-left', const Offset(40, 40)),
      ('top-right', const Offset(-40, 40)),
      ('bottom-left', const Offset(40, -40)),
      ('bottom-right', const Offset(-40, -40)),
    ]) {
      final before = cubit.state.crop;
      await tester.drag(find.byKey(ValueKey('crop-$corner')), by);
      await tester.pump();
      expect(cubit.state.crop, isNot(before), reason: corner);
    }
    final box = cubit.state.crop;
    expect(box.left, greaterThan(CropBox.start.left));
    expect(box.right, lessThan(CropBox.start.right));

    await tester.drag(
      find.byKey(const ValueKey('crop-box')),
      const Offset(30, 0),
    );
    await tester.pump();
    expect(cubit.state.crop.left, greaterThan(box.left));
    expect(
      cubit.state.crop.right - cubit.state.crop.left,
      closeTo(box.right - box.left, 1e-9),
    );

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(cubit.state.tool, PictureTool.none);
  });

  testWidgets('highlights where a finger is drawn', (tester) async {
    await pump(tester, state: ready());

    await tester.tap(find.text('Highlight'));
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey('picture-highlighter')),
      const Offset(80, 0),
    );
    await tester.pump();

    final stroke = cubit.state.strokes.single;
    expect(stroke.points.length, greaterThan(1));
    expect(stroke.points.last.x, greaterThan(stroke.points.first.x));

    // Another highlighter is taken up: its ink, then the thin one.
    await tester.tap(find.byKey(const ValueKey('ink-pink')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pen-thin')));
    await tester.pump();
    expect(cubit.state.color, HighlightColor.pink);
    expect(cubit.state.pen, HighlightPen.thin);
    expect(find.bySemanticsLabel('Pink'), findsOneWidget);
    expect(find.bySemanticsLabel('Thick'), findsOneWidget);

    // Another line is painted beside the first, in that pen.
    cubit.begin(const Point(0.1, 0.1));
    await tester.pump();
    expect(cubit.state.strokes, hasLength(2));
    expect(cubit.state.strokes.last.color, HighlightColor.pink);
    expect(cubit.state.strokes.first.color, HighlightColor.yellow);

    await tester.tap(find.text('Apply'));
    await tester.pump();
    expect(cubit.state.working, isTrue);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('turns the picture', (tester) async {
    await pump(tester, state: ready());

    await tester.tap(find.text('Turn'));
    await tester.pump();

    expect(cubit.state.working, isTrue);
    // Nothing else is begun meanwhile.
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Crop'))
          .enabled,
      isFalse,
    );
  });

  testWidgets('says when a change could not be made', (tester) async {
    await pump(tester, state: ready(failed: true));

    expect(find.text('That change could not be made.'), findsOneWidget);
    expect(find.text('Crop'), findsOneWidget);
  });

  testWidgets('offers saving and taking back once it is changed, but not '
      'with a tool in hand or mid-change', (tester) async {
    await pump(tester, state: ready(changed: true));
    expect(find.text('Save'), findsOneWidget);
    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();

    cubit.emit(ready(changed: true, working: true));
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
          .enabled,
      isFalse,
    );

    cubit.emit(ready(changed: true, tool: PictureTool.crop));
    await tester.pump();
    expect(find.text('Save'), findsNothing);
  });

  group('openPicture', () {
    Future<List<File?>> open(
      WidgetTester tester, {
      bool editable = true,
    }) async {
      final answers = <File?>[];
      await tester.pumpApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => answers.add(
              await openPicture(context, picture, editable: editable),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      return answers;
    }

    PictureCubit opened(WidgetTester tester) =>
        BlocProvider.of(tester.element(find.byType(PictureViewView)));

    testWidgets('opens it full screen, and answers with nothing when it was '
        'only looked at', (tester) async {
      final answers = await open(tester, editable: false);

      expect(find.byType(PictureViewPage), findsOneWidget);
      expect(opened(tester).state.file.path, picture.path);

      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(answers, [null]);
    });

    testWidgets('answers with the picture that was saved', (tester) async {
      final answers = await open(tester);
      final changed = File('${directory.path}/changed.jpg')
        ..writeAsBytesSync(grey());
      opened(
        tester,
      ).emit(PictureState(file: changed, width: 40, height: 20, changed: true));
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.byType(PictureViewPage), findsNothing);
      expect(answers.single!.path, changed.path);
    });
  });
}
