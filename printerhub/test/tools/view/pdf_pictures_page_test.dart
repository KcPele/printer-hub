import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/tools/tools.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;

  setUp(() async {
    backend = TestBackend();
    backend.picker.next = pickedPdfFile(backend.scans);
    await backend.signedInBefore();
  });
  tearDown(() => backend.close());

  /// Lets the pictures, which are made away from the screen, be made.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 200; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();
  }

  testWidgets('makes a picture of each page, and shares them', (tester) async {
    await tester.pumpApp(const PdfPicturesPage(long: false), backend: backend);

    expect(find.text('PDF to pictures'), findsOneWidget);
    await tester.tap(find.text('Choose a PDF'));
    await settle(tester);

    expect(find.text('Your 2 pictures are ready'), findsOneWidget);
    expect(find.text('Report 1.jpg'), findsOneWidget);
    expect(find.text('Report 2.jpg'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Share'));
    await tester.pump();
    expect(backend.sharer.shared.single.files, hasLength(2));
  });

  testWidgets('makes one tall picture', (tester) async {
    await tester.pumpApp(const PdfPicturesPage(long: true), backend: backend);

    expect(find.text('PDF to long picture'), findsOneWidget);
    expect(find.textContaining('top to bottom'), findsOneWidget);
    await tester.tap(find.text('Choose a PDF'));
    await settle(tester);

    expect(find.text('Your picture is ready'), findsOneWidget);
    expect(find.text('Report.jpg'), findsOneWidget);
  });

  testWidgets('says when the PDF cannot be read', (tester) async {
    backend.renderer.unreadable = true;
    await tester.pumpApp(const PdfPicturesPage(long: false), backend: backend);

    await tester.tap(find.text('Choose a PDF'));
    await settle(tester);

    expect(find.textContaining('could not be read'), findsOneWidget);
  });
}
