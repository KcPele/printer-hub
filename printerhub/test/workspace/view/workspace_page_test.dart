import 'package:api_client/testing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/session/session.dart';
import 'package:printerhub/workspace/workspace.dart';

import '../../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';

void main() {
  late TestBackend backend;
  late MockGoRouter router;

  setUp(() {
    backend = TestBackend();
    router = recordingRouter();
  });
  tearDown(() => backend.close());

  Future<void> pump(WidgetTester tester, {String role = 'owner'}) async {
    backend.workspaces = [organizationBody(role: role)];
    await tester.runAsync(backend.signedInBefore);
    await tester.pumpApp(
      const WorkspacePage(),
      backend: backend,
      router: router,
    );
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pump();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  group('WorkspacePage', () {
    testWidgets('shows the name and the rules to someone who manages it', (
      tester,
    ) async {
      await pump(tester);

      expect(find.widgetWithText(TextFormField, 'Acme'), findsOneWidget);
      expect(find.text('Rules for everyone'), findsOneWidget);
      expect(find.text('Most copies in one job'), findsOneWidget);
      expect(find.text('Keep documents in the workspace'), findsOneWidget);
      expect(find.text('Delete this workspace'), findsOneWidget);
    });

    testWidgets('shows the rules, unchangeable, to an ordinary member', (
      tester,
    ) async {
      await pump(tester, role: 'user');

      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Acme'), findsOneWidget);
      expect(find.text('No limit'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('An owner or admin sets these.'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      expect(find.text('What has been done'), findsNothing);
      expect(find.text('Delete this workspace'), findsNothing);
      expect(find.text('Leave this workspace'), findsOneWidget);
    });

    testWidgets('shows rules that are set to an ordinary member', (
      tester,
    ) async {
      final body = organizationBody(role: 'user');
      backend.workspaces = [
        {
          ...body,
          'settings': {
            ...body['settings']! as Map<String, Object?>,
            'max_copies_per_job': 25,
            'document_storage_mode': 'local_only',
          },
        },
      ];
      await tester.runAsync(backend.signedInBefore);
      await tester.pumpApp(const WorkspacePage(), backend: backend);
      await tester.pumpAndSettle();

      expect(find.text('25'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);
    });

    testWidgets('saves a new name and new rules', (tester) async {
      await pump(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Acme'),
        'Acme Ltd',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Most copies in one job'),
        '20',
      );
      await press(tester, find.text('Keep documents in the workspace'));
      await press(tester, find.widgetWithText(FilledButton, 'Save'));

      expect(find.text('Saved'), findsOneWidget);
      final saved = backend.workspaces.single;
      expect(saved['name'], 'Acme Ltd');
      expect((saved['settings']! as Map)['max_copies_per_job'], 20);
      expect(
        (saved['settings']! as Map)['document_storage_mode'],
        'local_only',
      );
      // The rest of the app has the new name too.
      final session = BlocProvider.of<SessionCubit>(
        tester.element(find.byType(WorkspaceView)),
      );
      expect(session.state.organization!.name, 'Acme Ltd');
      verifyNever(() => router.go(any(), extra: any(named: 'extra')));
    });

    testWidgets('takes a limit away when the field is emptied', (tester) async {
      final body = organizationBody();
      backend.workspaces = [
        {
          ...body,
          'settings': {
            ...body['settings']! as Map<String, Object?>,
            'max_copies_per_job': 25,
          },
        },
      ];
      await tester.runAsync(backend.signedInBefore);
      await tester.pumpApp(const WorkspacePage(), backend: backend);
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, '25'), '');
      await press(tester, find.widgetWithText(FilledButton, 'Save'));

      expect(
        (backend.workspaces.single['settings']! as Map)['max_copies_per_job'],
        isNull,
      );
    });

    testWidgets('does not save a workspace with no name, or a limit that '
        'makes no sense', (tester) async {
      await pump(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Acme'), ' ');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Most copies in one job'),
        '0',
      );
      await press(tester, find.widgetWithText(FilledButton, 'Save'));

      expect(find.text('Give the workspace a name.'), findsOneWidget);
      expect(find.textContaining('from 1 to 9999'), findsOneWidget);
      expect(backend.sent('PATCH /organizations/$_org'), isEmpty);
    });

    testWidgets('says why the workspace could not be saved', (tester) async {
      await pump(tester);
      backend.fail(
        'PATCH /organizations/$_org',
        403,
        'permission.denied',
        detail: 'Your role does not allow this action.',
      );

      await press(tester, find.widgetWithText(FilledButton, 'Save'));

      expect(find.text('Your role does not allow this action.'), findsOne);
    });

    testWidgets('opens the log', (tester) async {
      await pump(tester);

      await press(tester, find.text('What has been done'));

      verify(() => router.push<Object?>(AppRoutes.workspaceLog)).called(1);
    });

    testWidgets('leaves once that is confirmed', (tester) async {
      await pump(tester);

      await press(tester, find.text('Leave this workspace'));
      expect(find.text('Leave Acme?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(backend.workspaces, hasLength(1));

      await press(tester, find.text('Leave this workspace'));
      await tester.tap(find.widgetWithText(TextButton, 'Leave'));
      await tester.pumpAndSettle();

      expect(backend.workspaces, isEmpty);
      expect(find.text('You left Acme'), findsOneWidget);
      verify(() => router.go(AppRoutes.settings)).called(1);
    });

    testWidgets('deletes once that is confirmed', (tester) async {
      await pump(tester);

      await press(tester, find.text('Delete this workspace'));
      expect(find.text('Delete Acme?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(backend.workspaces, isEmpty);
      expect(find.text('Acme was deleted'), findsOneWidget);
      verify(() => router.go(AppRoutes.settings)).called(1);
    });

    testWidgets('says why the workspace cannot be read, and tries again', (
      tester,
    ) async {
      backend.workspaces = [organizationBody()];
      await tester.runAsync(backend.signedInBefore);
      backend.offline = true;
      await tester.pumpApp(const WorkspacePage(), backend: backend);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.text('The workspace could not be read'), findsOneWidget);

      backend.offline = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Rules for everyone'), findsOneWidget);
    });

    testWidgets('is empty for the moment there is no workspace', (
      tester,
    ) async {
      await tester.pumpApp(const WorkspacePage(), backend: backend);

      expect(find.byType(WorkspaceView), findsNothing);
    });
  });
}
