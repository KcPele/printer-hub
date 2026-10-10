import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
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
      ('PDF to pictures', AppRoutes.pdfToPictures),
      ('PDF to long picture', AppRoutes.pdfToLongPicture),
    ]) {
      await tester.scrollUntilVisible(find.text(tool), 120);
      await tester.tap(find.text(tool));
      verify(() => router.push<Object?>(route)).called(1);
    }
  });

  testWidgets('leaves out what cannot work here', (tester) async {
    await pump(tester);

    expect(find.text('Scan with your phone'), findsNothing);
    expect(find.text('Extract text'), findsNothing);
    expect(find.text('Pictures to PDF'), findsOneWidget);
  });
}
