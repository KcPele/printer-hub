import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/session/session.dart';

import '../../helpers/helpers.dart';

void main() {
  group('CreateWorkspacePage', () {
    late TestBackend backend;

    setUp(() async {
      backend = TestBackend();
      await backend.signedInBefore(withWorkspace: false);
    });
    tearDown(() => backend.close());

    Future<SessionCubit> pump(WidgetTester tester) async {
      final cubit = SessionCubit(
        authRepository: backend.auth,
        organizationsRepository: backend.organizations,
        preferencesRepository: emptyPreferences(),
      );
      addTearDown(cubit.close);
      await tester.pumpApp(
        const CreateWorkspacePage(),
        backend: backend,
        sessionCubit: cubit,
      );
      return cubit;
    }

    String nameIn(WidgetTester tester) {
      return tester
          .widget<TextFormField>(find.byType(TextFormField))
          .controller!
          .text;
    }

    testWidgets('suggests a name from the first name', (tester) async {
      await pump(tester);

      expect(nameIn(tester), "Ada's workspace");
    });

    testWidgets('suggests nothing for a user without a name', (tester) async {
      backend.user = {...backend.user, 'name': ' '};
      // A request made directly from a widget test runs outside its fake
      // clock, or it never completes.
      // A request awaited directly in a widget test runs outside its fake
      // clock, or it never completes.
      await tester.runAsync(backend.auth.refresh);

      await pump(tester);

      expect(nameIn(tester), isEmpty);
    });

    testWidgets('needs a name', (tester) async {
      await pump(tester);
      await tester.fill('Workspace name', '  ');

      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.text('Give the workspace a name.'), findsOneWidget);
      expect(backend.sent('POST /organizations'), isEmpty);
    });

    testWidgets('creates the workspace and starts using it', (tester) async {
      final cubit = await pump(tester);
      await tester.fill('Workspace name', ' Print room ');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(backend.lastBody('POST /organizations'), {'name': 'Print room'});
      expect(cubit.state.stage, SessionStage.ready);
      expect(cubit.state.organization?.name, 'Print room');
    });

    testWidgets('says when it could not be created', (tester) async {
      backend.offline = true;
      await pump(tester);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.textContaining("Can't reach PrinterHub"), findsOneWidget);
    });

    testWidgets('lets the user sign out instead', (tester) async {
      final cubit = await pump(tester);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(cubit.state.stage, SessionStage.signedOut);
    });
  });
}
