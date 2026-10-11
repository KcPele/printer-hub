import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/pictures/pictures.dart';

import '../../helpers/helpers.dart';
import '../picture_edits_test.dart' show grey;

void main() {
  late Directory directory;
  late File picture;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('openable_picture');
    picture = File('${directory.path}/photo.jpg')..writeAsBytesSync(grey());
  });
  tearDown(() => directory.deleteSync(recursive: true));

  PictureCubit opened(WidgetTester tester) =>
      BlocProvider.of(tester.element(find.byType(PictureViewView)));

  testWidgets('opens the picture full screen to change, and hands back '
      'what was saved', (tester) async {
    final changes = <File>[];
    await tester.pumpApp(
      OpenablePicture(
        picture: picture,
        onChanged: changes.add,
        child: const SizedBox.square(dimension: 56, child: Text('small')),
      ),
    );

    await tester.tap(find.text('small'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final changed = File('${directory.path}/changed.jpg')
      ..writeAsBytesSync(grey());
    opened(
      tester,
    ).emit(PictureState(file: changed, width: 40, height: 20, changed: true));
    await tester.pump();
    // It can be changed here.
    expect(find.text('Crop'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(changes.single.path, changed.path);
  });

  testWidgets('only shows a picture nothing is listening for changes to', (
    tester,
  ) async {
    await tester.pumpApp(
      OpenablePicture(picture: picture, child: const Text('small')),
    );

    await tester.tap(find.text('small'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    opened(tester).emit(PictureState(file: picture, width: 40, height: 20));
    await tester.pump();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Crop'), findsNothing);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(PictureViewPage), findsNothing);
  });
}
