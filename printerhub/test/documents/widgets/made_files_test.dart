import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/documents/documents.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;
  late MockGoRouter router;

  setUp(() {
    backend = TestBackend();
    router = recordingRouter();
  });
  tearDown(() => backend.close());

  Future<void> pump(WidgetTester tester, List<File> files) async {
    await tester.pumpApp(
      Scaffold(
        body: SingleChildScrollView(child: MadeFiles(files: files)),
      ),
      backend: backend,
      router: router,
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('shows each file as it looks, by name, and opens the one '
      'that is touched', (tester) async {
    backend.renderer.firstPage = tinyPng;
    final photo = File(pickedPicture(backend.scans, name: 'Resume 1.jpg').path);
    final sign = File(pickedPdfFile(backend.scans, name: 'Sign.pdf').path);

    await pump(tester, [photo, sign]);

    expect(find.text('Resume 1.jpg'), findsOneWidget);
    expect(find.text('Sign.pdf'), findsOneWidget);
    // Both are pictures now, not signs for their kind.
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsNothing);

    await tester.tap(find.text('Sign.pdf'));
    final opened = verify(
      () => router.push<Object?>(
        AppRoutes.documentView,
        extra: captureAny(named: 'extra'),
      ),
    )..called(1);
    final document = opened.captured.single as OpenDocument;
    expect(document.file.path, sign.path);
    expect(document.name, 'Sign.pdf');
    expect(document.mimeType, 'application/pdf');
  });

  testWidgets('shows a file it cannot draw by the sign for its kind, and '
      'still opens it', (tester) async {
    final sign = File(pickedPdfFile(backend.scans, name: 'Sign.pdf').path);

    await pump(tester, [sign]);

    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
    await tester.tap(find.text('Sign.pdf'));
    verify(
      () => router.push<Object?>(
        AppRoutes.documentView,
        extra: any(named: 'extra'),
      ),
    ).called(1);
  });
}
