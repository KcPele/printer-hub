import 'package:api_client/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/documents/documents.dart';
import 'package:printerhub/print/print.dart';
import 'package:printerhub/printers/printers.dart';

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
    // The menu closes. What the entry started may take real time: a file
    // being fetched is waited for with `settle`.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
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

    group('printing', () {
      late MockGoRouter router;
      late PrintersCubit printers;

      setUp(() {
        router = recordingRouter();
        printers = PrintersCubit(
          printersRepository: backend.printers,
          organizationId: _org,
          organizationChanges: const Stream.empty(),
        );
      });
      tearDown(() => printers.close());

      /// Opens the documents in a workspace that has [has] for printers.
      Future<void> open(
        WidgetTester tester,
        List<Map<String, Object?>> has,
      ) async {
        backend.printerList = has;
        final listed = await tester.runAsync(() => backend.printers.list(_org));
        printers.emit(
          PrintersState(status: PrintersStatus.ready, printers: listed!),
        );
        await tester.pumpApp(
          const DocumentsPage(),
          backend: backend,
          printersCubit: printers,
          router: router,
        );
        await tester.pumpAndSettle();
      }

      PickedDocument handedTo(String printerId) =>
          verify(
                () => router.go(
                  AppRoutes.printOn(printerId),
                  extra: captureAny(named: 'extra'),
                ),
              ).captured.single
              as PickedDocument;

      testWidgets('prints on the only printer without asking which', (
        tester,
      ) async {
        await open(tester, [printerBody()]);

        await menu(tester, 'Contract.pdf', 'Print');
        await settle(tester);

        final handed = handedTo('printer-1');
        expect(handed.name, 'Contract.pdf');
        expect(handed.mimeType, 'application/pdf');
        expect(handed.length, '%PDF a contract'.length);
      });

      testWidgets('asks which printer when there are several', (tester) async {
        await open(tester, [
          printerBody(),
          printerBody(id: 'printer-2', name: 'Back office'),
        ]);

        await menu(tester, 'Contract.pdf', 'Print');
        expect(find.text('Which printer?'), findsOneWidget);
        await tester.tap(find.text('Back office'));
        await settle(tester);

        expect(handedTo('printer-2').name, 'Contract.pdf');
      });

      testWidgets('fetches nothing when no printer is chosen', (tester) async {
        await open(tester, [
          printerBody(),
          printerBody(id: 'printer-2', name: 'Back office'),
        ]);

        await menu(tester, 'Contract.pdf', 'Print');
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(
          backend.sent('GET $_documents/document-3/download-url'),
          isEmpty,
        );
        verifyNever(() => router.go(any(), extra: any(named: 'extra')));
      });

      testWidgets('goes nowhere when the file cannot be fetched', (
        tester,
      ) async {
        await open(tester, [printerBody()]);

        // Nothing was ever stored for this one.
        await menu(tester, 'Receipts.pdf', 'Print');
        await settle(tester);

        expect(find.textContaining('could not be fetched'), findsOneWidget);
        verifyNever(() => router.go(any(), extra: any(named: 'extra')));
      });

      testWidgets('is not offered without a printer that prints', (
        tester,
      ) async {
        final scanner = printerBody();
        final capabilities = scanner['capabilities']! as Map<String, Object?>;
        await open(tester, [
          {
            ...scanner,
            'capabilities': {
              ...capabilities,
              'print': {
                ...capabilities['print']! as Map<String, Object?>,
                'supported': false,
              },
            },
          },
        ]);

        await tester.tap(find.byTooltip('Show menu').first);
        await tester.pumpAndSettle();

        expect(find.text('Open or share'), findsOneWidget);
        expect(find.text('Print'), findsNothing);
      });

      testWidgets('is not offered for a kind of file the app does not print', (
        tester,
      ) async {
        backend.documentList = [
          documentBody(name: 'Notes.txt', mimeType: 'text/plain'),
        ];
        backend.storage.stored['/document-1'] = 'notes'.codeUnits;
        await open(tester, [printerBody()]);

        await tester.tap(find.byTooltip('Show menu'));
        await tester.pumpAndSettle();

        expect(find.text('Open or share'), findsOneWidget);
        expect(find.text('Print'), findsNothing);
      });
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
