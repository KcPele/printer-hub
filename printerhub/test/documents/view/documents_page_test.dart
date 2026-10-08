import 'package:api_client/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/documents/documents.dart';

import '../../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';
const _documents = '/organizations/$_org/documents';

void main() {
  late TestBackend backend;

  setUp(() async {
    backend = TestBackend()
      ..documentList = [
        documentBody(id: 'document-3', name: 'Contract.pdf'),
        documentBody(
          id: 'document-2',
          name: 'Photo.jpg',
          mimeType: 'image/jpeg',
          pageCount: null,
        ),
        documentBody(),
      ];
    backend.storage.stored['/document-3'] = '%PDF a contract'.codeUnits;
    await backend.signedInBefore();
  });
  tearDown(() => backend.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpApp(const DocumentsPage(), backend: backend);
    await tester.pumpAndSettle();
  }

  /// Lets a file, which takes real time to fetch, arrive.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
  }

  Future<void> menu(WidgetTester tester, String document, String entry) async {
    await tester.tap(
      find.descendant(
        of: find.ancestor(of: find.text(document), matching: find.byType(Row)),
        matching: find.byTooltip('Show menu'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(entry).last);
    await tester.pumpAndSettle();
  }

  group('DocumentsPage', () {
    testWidgets('says what will appear, before anything has', (tester) async {
      backend.documentList = [];

      await pump(tester);

      expect(find.text('No documents yet'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('lists each document with what is known of it', (tester) async {
      await pump(tester);

      expect(find.text('Contract.pdf'), findsOneWidget);
      expect(find.textContaining('3 pages · 2 KB · '), findsNWidgets(2));
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsNWidgets(2));
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets('says where a file is when the workspace has none', (
      tester,
    ) async {
      backend.documentList = [
        documentBody(storageMode: 'local', uploadStatus: 'not_applicable'),
        documentBody(
          id: 'document-2',
          name: 'Half.pdf',
          uploadStatus: 'pending',
        ),
      ];

      await pump(tester);

      expect(find.text('On the phone that made it'), findsOneWidget);
      expect(find.text('Did not finish uploading'), findsOneWidget);

      // Neither can be opened, by a tap or from its menu.
      await tester.tap(find.text('Half.pdf'));
      await tester.pumpAndSettle();
      expect(backend.sent('GET $_documents/document-2/download-url'), isEmpty);
      await tester.tap(find.byTooltip('Show menu').last);
      await tester.pumpAndSettle();
      expect(find.text('Open or share'), findsNothing);
      expect(find.text('Rename'), findsOneWidget);
    });

    testWidgets('searches when asked', (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'contract');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.text('Contract.pdf'), findsOneWidget);
      expect(find.text('Photo.jpg'), findsNothing);
    });

    testWidgets('says when nothing matches', (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'invoice');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('Nothing by that name.'), findsOneWidget);
    });

    testWidgets('reads earlier documents when asked', (tester) async {
      backend.documentPageSize = 2;
      await pump(tester);
      expect(find.text('Receipts.pdf'), findsNothing);

      await tester.tap(find.text('Show earlier'));
      await tester.pumpAndSettle();

      expect(find.text('Receipts.pdf'), findsOneWidget);
      expect(find.text('Show earlier'), findsNothing);
    });

    testWidgets('opens a document when it is tapped', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Contract.pdf'));
      await tester.pump();
      await settle(tester);

      expect(backend.sharer.shared.single.name, 'Contract.pdf');
    });

    testWidgets('opens a document from its menu, showing it is at work', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.byTooltip('Show menu').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open or share'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await settle(tester);

      expect(backend.sharer.shared, hasLength(1));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('says when a file cannot be fetched', (tester) async {
      await pump(tester);

      // Nothing was ever stored for this one.
      await tester.tap(find.text('Receipts.pdf'));
      await settle(tester);

      expect(find.textContaining('could not be fetched'), findsOneWidget);
    });

    testWidgets('renames a document', (tester) async {
      await pump(tester);

      await menu(tester, 'Contract.pdf', 'Rename');
      // The same name is nothing to save.
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Lease.pdf',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Lease.pdf'), findsOneWidget);
      expect(backend.documentList.first['file_name'], 'Lease.pdf');
    });

    testWidgets('leaves the name alone when renaming is given up', (
      tester,
    ) async {
      await pump(tester);

      await menu(tester, 'Contract.pdf', 'Rename');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(backend.documentList.first['file_name'], 'Contract.pdf');
    });

    testWidgets('deletes a document once that is confirmed', (tester) async {
      await pump(tester);

      await menu(tester, 'Contract.pdf', 'Delete');
      expect(find.text('Delete Contract.pdf?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(backend.documentList, hasLength(3));

      await menu(tester, 'Contract.pdf', 'Delete');
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Contract.pdf'), findsNothing);
      expect(backend.documentList, hasLength(2));
    });

    testWidgets('says why a document could not be deleted', (tester) async {
      backend.fail(
        'DELETE $_documents/document-3',
        403,
        'permission.denied',
        detail: 'Only its owner can delete this document.',
      );
      await pump(tester);

      await menu(tester, 'Contract.pdf', 'Delete');
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Only its owner can delete this document.'), findsOne);
      expect(find.text('Contract.pdf'), findsOneWidget);
    });

    testWidgets('reads again when pulled down', (tester) async {
      await pump(tester);
      backend.documentList = [
        documentBody(id: 'document-4', name: 'Later.pdf'),
        ...backend.documentList,
      ];

      await tester.drag(find.text('Contract.pdf'), const Offset(0, 400));
      await tester.pumpAndSettle();

      expect(find.text('Later.pdf'), findsOneWidget);
    });

    testWidgets('says why the list cannot be read, and tries again', (
      tester,
    ) async {
      backend.offline = true;
      await pump(tester);

      expect(find.text('Your documents could not be read'), findsOneWidget);

      backend.offline = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Contract.pdf'), findsOneWidget);
    });
  });
}
