import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/scan/scan.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;
  late Directory directory;
  late List<File> pages;

  setUp(() {
    backend = TestBackend();
    directory = Directory.systemTemp.createTempSync('sign_page');
    pages = [
      for (final name in ['1.jpg', '2.jpg'])
        File('${directory.path}/$name')..writeAsBytesSync(tinyJpeg),
    ];
  });
  tearDown(() async {
    await backend.close();
    directory.deleteSync(recursive: true);
  });

  Uint8List kept() => img.encodePng(img.Image(width: 60, height: 20));

  /// Opens the signing screen over another, and says what it closed with.
  Future<List<PlacedSignature?>> open(
    WidgetTester tester, {
    int sheets = 2,
    PlacedSignature? placed,
  }) async {
    final closedWith = <PlacedSignature?>[];
    await tester.pumpApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => closedWith.add(
            await Navigator.of(context).push<PlacedSignature>(
              MaterialPageRoute(
                builder: (_) => SignPage(
                  pages: pages.take(sheets).toList(),
                  paper: ScanPaper.named('iso_a4_210x297mm'),
                  placed: placed,
                ),
              ),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
      backend: backend,
    );
    await tester.tap(find.text('Open'));
    await settle(tester);
    return closedWith;
  }

  SignCubit cubitOf(WidgetTester tester) =>
      BlocProvider.of<SignCubit>(tester.element(find.byType(SignView)));

  group('SignPage', () {
    testWidgets('opens the pad when no signature is kept, and takes what '
        'is drawn on it', (tester) async {
      await open(tester);

      expect(find.text('Use this signature'), findsOneWidget);
      // Nothing to use or clear before something is drawn.
      await press(tester, find.text('Use this signature'));
      await press(tester, find.text('Clear'));
      await tester.pump();
      expect(find.text('Place it here'), findsNothing);

      final pad = find.byKey(const ValueKey('signature-pad'));
      await tester.drag(pad, const Offset(90, 30));
      await tester.pump();
      expect(cubitOf(tester).state.drawn, isTrue);

      await press(tester, find.text('Clear'));
      await tester.pump();
      expect(cubitOf(tester).state.drawn, isFalse);

      await tester.drag(pad, const Offset(90, 30));
      await tester.pump();
      await press(tester, find.text('Use this signature'));
      await settle(tester);

      expect(find.text('Place it here'), findsOneWidget);
      expect(backend.signatureValues.values, isNotEmpty);
    });

    testWidgets('places a kept signature: dragged, sized, and on the sheet '
        'chosen', (tester) async {
      await tester.runAsync(() => backend.signatures.save(kept()));
      final closedWith = await open(tester);

      expect(find.text('Place it here'), findsOneWidget);
      final before = cubitOf(tester).state;
      // The last sheet is where a signature most often goes.
      expect(before.page, 1);

      final signature = find.byKey(const ValueKey('placed-signature'));
      await tester.ensureVisible(signature);
      await tester.pump();
      await tester.drag(signature, const Offset(-60, -80));
      await tester.pump();
      final moved = cubitOf(tester).state;
      expect(moved.x, lessThan(before.x));
      expect(moved.y, lessThan(before.y));

      await tester.ensureVisible(find.byType(Slider));
      await tester.pump();
      await tester.drag(find.byType(Slider), const Offset(200, 0));
      await tester.pump();
      expect(cubitOf(tester).state.width, greaterThan(before.width));

      await press(tester, find.text('Page 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Page 1').last);
      await tester.pumpAndSettle();
      expect(cubitOf(tester).state.page, 0);

      final last = cubitOf(tester).state;
      await press(tester, find.text('Place it here'));
      await tester.pumpAndSettle();

      final placed = closedWith.single!;
      expect(placed.page, 0);
      expect((placed.x, placed.y, placed.width), (last.x, last.y, last.width));
    });

    testWidgets('asks which sheet only when there is more than '
        'one', (tester) async {
      await tester.runAsync(() => backend.signatures.save(kept()));
      await open(tester, sheets: 1);

      expect(find.text('Place it here'), findsOneWidget);
      expect(find.text('On'), findsNothing);
    });

    testWidgets('shows a page it cannot draw as a sheet all the '
        'same', (tester) async {
      pages.first.writeAsStringSync('not a picture');
      await tester.runAsync(() => backend.signatures.save(kept()));
      await open(tester, sheets: 1);

      final placeholder = find.byIcon(Icons.image_outlined);
      for (var i = 0; i < 20 && placeholder.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }

      expect(placeholder, findsOneWidget);
      expect(find.byKey(const ValueKey('placed-signature')), findsOneWidget);
    });

    testWidgets('draws a new signature in place of the kept '
        'one', (tester) async {
      await tester.runAsync(() => backend.signatures.save(kept()));
      await open(tester);

      await press(tester, find.text('Draw a new signature'));
      await settle(tester);

      expect(find.text('Use this signature'), findsOneWidget);
      expect(backend.signatureValues.values, isEmpty);
    });

    testWidgets('closes with nothing when it is left', (tester) async {
      await tester.runAsync(() => backend.signatures.save(kept()));
      final closedWith = await open(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(closedWith, [null]);
    });
  });
}

Future<void> press(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target, warnIfMissed: false);
}

/// Lets what is read from the phone arrive.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
  }
  await tester.pumpAndSettle();
}
