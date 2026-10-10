import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/tools/tools.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;

  setUp(() => backend = TestBackend());
  tearDown(() => backend.close());

  /// Lets the reading, which touches real files, finish.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 50; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();
  }

  testWidgets('reads a file, shows its words, and copies and shares them', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    backend.picker.next = pickedPicture(backend.scans, name: 'Sign.jpg');
    await tester.pumpApp(const ExtractTextPage(), backend: backend);

    expect(find.text('Extract text'), findsOneWidget);
    expect(find.textContaining('read on this phone'), findsOneWidget);

    await tester.tap(find.text('Choose a file'));
    await settle(tester);

    expect(find.text('Sign'), findsOneWidget);
    expect(find.text('Invoice 42'), findsOneWidget);
    expect(find.textContaining('read on this phone'), findsNothing);

    await tester.tap(find.text('Copy the text'));
    await tester.pump();
    expect(copied, 'Invoice 42');
    expect(find.text('Copied.'), findsOneWidget);

    await tester.tap(find.text('Share as a text file'));
    // The text file is written first, which takes real time.
    for (var i = 0; i < 50 && backend.sharer.shared.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    expect(backend.sharer.shared.single.name, 'Sign');

    backend.picker.next = pickedPicture(backend.scans, name: 'Other.jpg');
    await tester.ensureVisible(find.text('Choose another'));
    await tester.tap(find.text('Choose another'));
    await settle(tester);
    expect(find.text('Other'), findsOneWidget);
  });

  testWidgets('says when a file has no words', (tester) async {
    backend.picker.next = pickedPicture(backend.scans);
    backend.textReader.text = '';
    await tester.pumpApp(const ExtractTextPage(), backend: backend);

    await tester.tap(find.text('Choose a file'));
    await settle(tester);

    expect(find.text('No words were found in that file.'), findsOneWidget);
    expect(find.text('Choose a file'), findsOneWidget);
  });
}
