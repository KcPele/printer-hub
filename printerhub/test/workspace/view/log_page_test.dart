import 'package:api_client/testing.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/workspace/workspace.dart';

import '../../helpers/helpers.dart';

const _me = '0198c0de-0000-7000-8000-000000000002';

void main() {
  late TestBackend backend;

  setUp(() {
    backend = TestBackend()
      ..auditList = [
        auditBody(
          id: 'audit-4',
          action: 'invitation.created',
          actorUserId: _me,
          detail: const {'email': 'alan@example.com'},
        ),
        auditBody(
          id: 'audit-3',
          action: 'printer.removed',
          actorUserId: 'someone-gone',
          outcome: 'failure',
        ),
        auditBody(id: 'audit-2', action: 'member.joined', actorUserId: null),
        auditBody(action: 'printer.added', actorUserId: 'user-2'),
      ];
  });
  tearDown(() => backend.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.runAsync(backend.signedInBefore);
    await tester.pumpApp(const WorkspaceLogPage(), backend: backend);
    await tester.pumpAndSettle();
  }

  group('WorkspaceLogPage', () {
    testWidgets('says what was done, to what, by whom, and when', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Invited someone: alan@example.com'), findsOneWidget);
      expect(find.textContaining('Ada · Wed, Oct 7 at '), findsOneWidget);
      expect(find.text('Removed a printer'), findsOneWidget);
      expect(find.textContaining('Someone who has left · '), findsOneWidget);
      expect(find.widgetWithText(StatusPill, 'Did not work'), findsOneWidget);
      expect(find.textContaining('PrinterHub · '), findsOneWidget);
      expect(find.textContaining('Grace Hopper · '), findsOneWidget);
    });

    testWidgets('says when nothing has been recorded', (tester) async {
      backend.auditList = [];

      await pump(tester);

      expect(find.text('Nothing has been recorded yet.'), findsOneWidget);
    });

    testWidgets('reads earlier entries when asked', (tester) async {
      backend.auditPageSize = 3;
      await pump(tester);
      expect(find.text('Added a printer'), findsNothing);

      await tester.scrollUntilVisible(find.text('Show earlier'), 200);
      await tester.tap(find.text('Show earlier'));
      await tester.pumpAndSettle();

      expect(find.text('Added a printer'), findsOneWidget);
    });

    testWidgets('says when earlier entries cannot be read', (tester) async {
      backend.auditPageSize = 3;
      await pump(tester);
      backend.offline = true;

      await tester.scrollUntilVisible(find.text('Show earlier'), 200);
      await tester.tap(find.text('Show earlier'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.textContaining("Can't reach PrinterHub"),
        -200,
      );
      expect(find.text('Removed a printer'), findsOneWidget);
    });

    testWidgets('reads again when pulled down', (tester) async {
      await pump(tester);
      backend.auditList = [
        auditBody(id: 'audit-5', action: 'organization.updated'),
        ...backend.auditList,
      ];

      await tester.drag(find.text('Removed a printer'), const Offset(0, 400));
      await tester.pumpAndSettle();

      expect(find.text('Changed the workspace'), findsOneWidget);
    });

    testWidgets('says why the log cannot be read, and tries again', (
      tester,
    ) async {
      await tester.runAsync(backend.signedInBefore);
      backend.offline = true;
      await tester.pumpApp(const WorkspaceLogPage(), backend: backend);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.text('The log could not be read'), findsOneWidget);

      backend.offline = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Removed a printer'), findsOneWidget);
    });

    testWidgets('is empty for the moment there is no workspace', (
      tester,
    ) async {
      await tester.pumpApp(const WorkspaceLogPage(), backend: backend);

      expect(find.byType(WorkspaceLogView), findsNothing);
    });
  });
}
