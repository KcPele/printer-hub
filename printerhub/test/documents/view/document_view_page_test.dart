import 'dart:io';

import 'package:api_client/testing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/documents/documents.dart';
import 'package:printerhub/pictures/pictures.dart';
import 'package:printerhub/print/print.dart';
import 'package:printerhub/printers/printers.dart';
import 'package:printerhub/workspace/workspace.dart';

import '../../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';

void main() {
  late TestBackend backend;
  late MockGoRouter router;
  late PrintersCubit printers;

  setUp(() async {
    backend = TestBackend();
    router = recordingRouter();
    await backend.signedInBefore();
    printers = PrintersCubit(
      printersRepository: backend.printers,
      organizationId: _org,
      organizationChanges: const Stream.empty(),
    );
  });
  tearDown(() async {
    await printers.close();
    await backend.close();
  });

  OpenDocument pdf() => OpenDocument(
    file: File(pickedPdfFile(backend.scans, name: 'Contract.pdf').path),
    name: 'Contract.pdf',
    mimeType: 'application/pdf',
  );

  Future<void> pump(
    WidgetTester tester,
    OpenDocument document, {
    List<Map<String, Object?>> printerList = const [],
    Map<String, bool> features = const {},
  }) async {
    backend
      ..printerList = printerList
      ..features = features;
    final listed = await tester.runAsync(() => backend.printers.list(_org));
    printers.emit(
      PrintersState(status: PrintersStatus.ready, printers: listed!),
    );
    await tester.pumpApp(
      DocumentViewPage(document: document),
      backend: backend,
      printersCubit: printers,
      router: router,
    );
    await tester.runAsync(
      BlocProvider.of<FeaturesCubit>(
        tester.element(find.byType(DocumentViewView)),
      ).load,
    );
    // The pages are drawn a moment after the screen opens.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  DocumentViewCubit cubitOf(WidgetTester tester) =>
      BlocProvider.of(tester.element(find.byType(DocumentViewView)));

  /// Touches a page. A test never finishes reading a picture's file, so
  /// the page has no size to be tapped at.
  Future<void> touch(WidgetTester tester, Finder page) async {
    tester
        .widget<GestureDetector>(
          find.descendant(of: page, matching: find.byType(GestureDetector)),
        )
        .onTap!();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  /// Opens [small] full screen and saves [changed] there, as someone who
  /// changed the picture would.
  Future<void> saveChanged(
    WidgetTester tester,
    Finder small,
    File changed,
  ) async {
    await touch(tester, small);
    BlocProvider.of<PictureCubit>(tester.element(find.byType(PictureViewView)))
        .emit(PictureState(file: changed, width: 2, height: 2, changed: true));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  /// Lets the phone's files, which take real time, and the screen, which
  /// takes the test's, get on until [done].
  Future<void> until(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  OpenDocument photo() => OpenDocument(
    file: File(pickedPicture(backend.scans).path),
    name: 'Photo.jpg',
    mimeType: 'image/jpeg',
  );

  testWidgets('opens a page full screen when it is touched: a PDF’s only to '
      'look at', (tester) async {
    backend.renderer.pageCount = 2;
    await pump(tester, pdf());

    final pages = [for (final page in cubitOf(tester).state.pages) page.path];
    await touch(tester, find.byType(OpenablePicture).first);
    final opened = BlocProvider.of<PictureCubit>(
      tester.element(find.byType(PictureViewView)),
    );
    expect(pages, contains(opened.state.file.path));
    opened.emit(PictureState(file: opened.state.file, width: 2, height: 2));
    await tester.pump();

    expect(find.text('Crop'), findsNothing);
  });

  testWidgets('keeps a picture that was changed as a new document, and '
      'opens that one', (tester) async {
    await pump(tester, photo());
    // One page is shown whole, with no frame around it.
    expect(find.byType(ListView), findsNothing);
    final changed = File('${backend.scans.path}/picture-1.jpg')
      ..writeAsBytesSync(tinyJpeg);

    await saveChanged(tester, find.byType(OpenablePicture), changed);
    await until(
      tester,
      () => find.text('Saved as a new document').evaluate().isNotEmpty,
    );

    expect(find.text('Photo edited.jpg'), findsOneWidget);
    expect(cubitOf(tester).state.document.name, 'Photo edited.jpg');
  });

  testWidgets('says when a changed picture could not be saved', (tester) async {
    await pump(tester, photo());

    final changed = File('${backend.scans.path}/picture-1.jpg')
      ..writeAsBytesSync(tinyJpeg);
    // Something is in the way of the name it would be kept under.
    Directory('${backend.scans.path}/Photo edited.jpg').createSync();

    await saveChanged(tester, find.byType(OpenablePicture), changed);
    await until(
      tester,
      () => find
          .text('The changed picture could not be saved.')
          .evaluate()
          .isNotEmpty,
    );

    expect(find.text('Photo.jpg'), findsOneWidget);
  });

  testWidgets('shows a document’s pages, one under another', (tester) async {
    backend.renderer.pageCount = 2;
    await pump(tester, pdf());

    expect(find.text('Contract.pdf'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    expect(cubitOf(tester).state.pages, hasLength(2));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('prints on a printer of the workspace, and shares from '
      'beside it', (tester) async {
    await pump(tester, pdf(), printerList: [printerBody()]);

    await tester.tap(find.widgetWithText(FilledButton, 'Print'));
    await tester.pumpAndSettle();
    final sent = verify(
      () => router.go(
        AppRoutes.printOn('printer-1'),
        extra: captureAny(named: 'extra'),
      ),
    )..called(1);
    expect((sent.captured.single as PickedDocument).name, 'Contract.pdf');

    await tester.tap(find.byTooltip('Share'));
    await tester.pump();
    expect(backend.sharer.shared.single.name, 'Contract.pdf');
  });

  testWidgets('prints nothing when no printer is picked', (tester) async {
    await pump(
      tester,
      pdf(),
      printerList: [
        printerBody(),
        printerBody(id: 'printer-2', name: 'Back office'),
      ],
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Print'));
    await tester.pumpAndSettle();
    expect(find.text('Which printer?'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    verifyNever(() => router.go(any(), extra: any(named: 'extra')));
  });

  testWidgets('offers sharing first where there is no printer', (tester) async {
    await pump(tester, pdf());

    expect(find.widgetWithText(FilledButton, 'Print'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Share'));
    await tester.pump();

    expect(backend.sharer.shared, hasLength(1));
  });

  testWidgets('opens each tool on the document, with nothing to choose '
      'again', (tester) async {
    await pump(tester, pdf(), features: {'local_ocr': true});

    for (final (tool, route) in [
      ('Edit the pages', AppRoutes.documentEdit),
      ('Extract text', AppRoutes.documentText),
      ('PDF to pictures', AppRoutes.documentPictures),
      ('PDF to long picture', AppRoutes.documentLongPicture),
      ('Pages per sheet', AppRoutes.documentPerSheet),
    ]) {
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Do more with it'), findsOneWidget);
      await tester.tap(find.text(tool));
      await tester.pumpAndSettle();

      // The sheet has gone, and the tool was handed the document.
      expect(find.text('Do more with it'), findsNothing);
      final pushed = verify(
        () => router.push<Object?>(route, extra: captureAny(named: 'extra')),
      )..called(1);
      expect((pushed.captured.single as PickedDocument).name, 'Contract.pdf');
    }
  });

  testWidgets('offers a picture only what works on a picture, and reading '
      'only where the workspace has it on', (tester) async {
    final picture = File(pickedPicture(backend.scans).path);
    await pump(
      tester,
      OpenDocument(file: picture, name: 'Photo.jpg', mimeType: 'image/jpeg'),
    );

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    expect(find.text('Edit the pages'), findsOneWidget);
    expect(find.text('Extract text'), findsNothing);
    expect(find.text('PDF to pictures'), findsNothing);
  });

  testWidgets('says when it cannot show a document, which can still be '
      'shared', (tester) async {
    await pump(
      tester,
      OpenDocument(file: pdf().file, name: 'Notes.txt', mimeType: 'text/plain'),
    );

    expect(find.text('This document cannot be shown here'), findsOneWidget);
    // Nothing the app has works on it.
    expect(find.text('More'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Share'));
    await tester.pump();

    expect(backend.sharer.shared, hasLength(1));
  });

  testWidgets('waits while the first page is drawn', (tester) async {
    await tester.pumpApp(
      DocumentViewPage(document: pdf()),
      backend: backend,
      router: router,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('shows a page it cannot draw as a page all the same', (
    tester,
  ) async {
    final broken = File('${backend.scans.path}/Broken.jpg')
      ..writeAsStringSync('not a picture');
    await pump(
      tester,
      OpenDocument(file: broken, name: 'Broken.jpg', mimeType: 'image/jpeg'),
    );
    final placeholder = find.byIcon(Icons.image_outlined);
    for (var i = 0; i < 20 && placeholder.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }

    expect(placeholder, findsOneWidget);
  });
}
