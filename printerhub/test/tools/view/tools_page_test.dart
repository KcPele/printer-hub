import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/tools/tools.dart';
import 'package:printerhub/workspace/workspace.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;
  late MockGoRouter router;

  setUp(() async {
    backend = TestBackend();
    router = recordingRouter();
    await backend.signedInBefore();
  });
  tearDown(() => backend.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpApp(const ToolsPage(), backend: backend, router: router);
    await tester.runAsync(
      BlocProvider.of<FeaturesCubit>(tester.element(find.byType(ToolsPage)))
          .load,
    );
    await tester.pump();
  }

  testWidgets('lists every tool that works, and opens each', (tester) async {
    backend.features = {'camera_scan': true, 'local_ocr': true};
    await pump(tester);

    expect(find.textContaining('with or without a printer'), findsOneWidget);
    for (final (tool, route) in [
      ('Scan with your phone', AppRoutes.scan),
      ('Pictures to PDF', AppRoutes.picturesToPdf),
      ('Extract text', AppRoutes.extractText),
      ('Print photos', AppRoutes.photoSheet),
      ('PDF to pictures', AppRoutes.pdfToPictures),
      ('PDF to long picture', AppRoutes.pdfToLongPicture),
      ('Pages per sheet', AppRoutes.pagesPerSheet),
      ('Scan a code', AppRoutes.scanCode),
      ('Make a QR code', AppRoutes.codeSheet),
      ('Print a note', AppRoutes.note),
      ('Printable pages', AppRoutes.printable),
    ]) {
      await tester.scrollUntilVisible(find.text(tool), 120);
      await tester.ensureVisible(find.text(tool));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tool));
      verify(() => router.push<Object?>(route)).called(1);
    }

    // Joining files and keeping some pages are one screen, begun with
    // files.
    for (final tool in ['Merge files', 'Take pages from a PDF']) {
      await tester.scrollUntilVisible(find.text(tool), 120);
      await tester.ensureVisible(find.text(tool));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tool));
    }
    verify(() => router.push<Object?>(AppRoutes.filesToPdf)).called(2);
  });

  testWidgets('shows what is planned, greyed and not to be opened', (
    tester,
  ) async {
    // As wide as a phone, where a card has little room.
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pump(tester);

    // Every tool that works on the phone works now: what is planned
    // needs AI.
    await tester.scrollUntilVisible(find.text('To Word'), 120);
    expect(find.text('Coming soon', skipOffstage: false), findsNothing);
    expect(
      find.text('Coming soon: AI tools', skipOffstage: false),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('To Word'));
    await tester.pumpAndSettle();

    final tile = tester.widget<ToolTile>(
      find.ancestor(of: find.text('To Word'), matching: find.byType(ToolTile)),
    );
    expect(tile.onTap, isNull);
    await tester.tap(find.text('To Word'));
    verifyNever(() => router.push<Object?>(any()));
  });

  testWidgets('leaves out what cannot work here', (tester) async {
    await pump(tester);

    expect(find.text('Scan with your phone'), findsNothing);
    expect(find.text('Extract text'), findsNothing);
    expect(find.text('Pictures to PDF'), findsOneWidget);
  });
}
