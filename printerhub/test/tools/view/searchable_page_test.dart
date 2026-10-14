import 'package:api_client/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/documents/documents.dart';
import 'package:printerhub/tools/tools.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;

  setUp(() async {
    backend = TestBackend();
    await backend.signedInBefore();
  });
  tearDown(() => backend.close());

  /// Lets the reading and the PDF, which touch real files, finish.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();
  }

  testWidgets('makes a searchable PDF, and shows and shares it', (
    tester,
  ) async {
    backend.picker.next = pickedPicture(backend.scans, name: 'Receipt.jpg');
    await tester.pumpApp(const SearchablePage(), backend: backend);

    expect(find.text('Searchable PDF'), findsOneWidget);
    expect(find.textContaining('read on your phone'), findsOneWidget);

    await tester.tap(find.text('Choose a file'));
    await settle(tester);

    expect(find.text('Your searchable PDF is ready'), findsOneWidget);
    expect(find.text('Receipt searchable.pdf'), findsOneWidget);
    expect(find.byType(MadeFiles), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Share'));
    await tester.pump();
    expect(backend.sharer.shared, hasLength(1));
  });

  testWidgets('works on a document that is already open', (tester) async {
    await tester.pumpApp(
      SearchablePage(document: pickedPicture(backend.scans)),
      backend: backend,
    );
    await settle(tester);

    expect(find.text('Your searchable PDF is ready'), findsOneWidget);
    expect(backend.picker.opened, 0);
  });

  testWidgets('shows what it made before, below the button', (tester) async {
    backend.documentList = [
      documentBody(name: 'Old searchable.pdf', source: 'searchable_pdf'),
      documentBody(id: 'document-2', name: 'Scan.pdf'),
    ];
    await tester.pumpApp(const SearchablePage(), backend: backend);
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.text('Old searchable.pdf'), findsOneWidget);
    expect(find.text('Scan.pdf'), findsNothing);
  });
}
