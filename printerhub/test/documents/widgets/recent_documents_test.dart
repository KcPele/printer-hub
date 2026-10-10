import 'package:api_client/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/documents/view/documents_page.dart';
import 'package:printerhub/documents/widgets/recent_documents.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;
  late MockGoRouter router;

  setUp(() {
    backend = TestBackend()
      ..documentList = [
        for (var i = 4; i > 0; i--)
          documentBody(id: 'document-$i', name: 'Scan $i.pdf'),
      ];
    router = recordingRouter();
  });
  tearDown(() => backend.close());

  Future<void> pump(WidgetTester tester, {int limit = 3}) async {
    await tester.pumpApp(
      Scaffold(
        body: SingleChildScrollView(
          child: RecentDocuments(title: 'Recent documents', limit: limit),
        ),
      ),
      backend: backend,
      router: router,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the last few documents, and leads to the rest', (
    tester,
  ) async {
    await tester.runAsync(backend.signedInBefore);
    await pump(tester);

    expect(find.text('Recent documents'), findsOneWidget);
    expect(find.byType(DocumentCard), findsNWidgets(3));
    expect(find.text('Scan 4.pdf'), findsOneWidget);
    expect(find.text('Scan 1.pdf'), findsNothing);

    await tester.tap(find.text('See all'));
    verify(() => router.push<Object?>(AppRoutes.documents)).called(1);
  });

  testWidgets('shows as many as it is asked for', (tester) async {
    await tester.runAsync(backend.signedInBefore);
    await pump(tester, limit: 1);

    expect(find.byType(DocumentCard), findsOneWidget);
  });

  testWidgets('shows nothing until there is a document', (tester) async {
    backend.documentList = [];
    await tester.runAsync(backend.signedInBefore);
    await pump(tester);

    expect(find.text('Recent documents'), findsNothing);
    expect(find.text('See all'), findsNothing);
  });

  testWidgets('shows nothing to someone with no workspace', (tester) async {
    await pump(tester);

    expect(find.text('Recent documents'), findsNothing);
    expect(backend.sent('GET /organizations'), isEmpty);
  });

  testWidgets('each document can be acted on where it is shown', (
    tester,
  ) async {
    await tester.runAsync(backend.signedInBefore);
    await pump(tester);

    await tester.tap(find.byTooltip('Show menu').first);
    await tester.pumpAndSettle();

    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });
}
