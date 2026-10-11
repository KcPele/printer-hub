import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/documents/documents.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;

  setUp(() => backend = TestBackend());
  tearDown(() => backend.close());

  Future<void> pump(
    WidgetTester tester, {
    String mimeType = 'application/pdf',
  }) async {
    await tester.pumpApp(
      DocumentViewPage(
        file: File(pickedPdfFile(backend.scans).path),
        name: 'Contract.pdf',
        mimeType: mimeType,
      ),
      backend: backend,
    );
    // The pages are drawn a moment after the screen opens.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('shows a document’s pages, one under another', (tester) async {
    backend.renderer.pageCount = 2;
    await pump(tester);

    expect(find.text('Contract.pdf'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    expect(
      BlocProvider.of<DocumentViewCubit>(
        tester.element(find.byType(DocumentViewView)),
      ).state.pages,
      hasLength(2),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shares the document from the top of the screen', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Share'));
    await tester.pump();

    expect(backend.sharer.shared.single.name, 'Contract.pdf');
  });

  testWidgets('says when it cannot show a document, and offers to share it '
      'instead', (tester) async {
    await pump(tester, mimeType: 'text/plain');

    expect(find.text('This document cannot be shown here'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Share'));
    await tester.pump();

    expect(backend.sharer.shared, hasLength(1));
  });

  testWidgets('waits while the first page is drawn', (tester) async {
    await tester.pumpApp(
      DocumentViewPage(
        file: File(pickedPdfFile(backend.scans).path),
        name: 'Contract.pdf',
        mimeType: 'application/pdf',
      ),
      backend: backend,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
  });
}
