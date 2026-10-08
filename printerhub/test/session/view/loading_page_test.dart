import 'package:api_client/testing.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/session/session.dart';

import '../../helpers/helpers.dart';

void main() {
  group('LoadingPage', () {
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
        const LoadingPage(),
        backend: backend,
        sessionCubit: cubit,
      );
      return cubit;
    }

    // The page shows a spinner, which never settles, so time is moved on by
    // hand to let a request finish.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('shows progress while the workspaces load', (tester) async {
      await pump(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Getting things ready'), findsOneWidget);
      expect(find.byType(AppLogo), findsOneWidget);
    });

    testWidgets('says why loading failed and tries again', (tester) async {
      backend.offline = true;
      final cubit = await pump(tester);
      await tester.runAsync(cubit.loadWorkspaces);
      await tester.pump();

      expect(find.textContaining("Can't reach PrinterHub"), findsOneWidget);

      backend
        ..offline = false
        ..workspaces = [organizationBody()];
      await tester.tap(find.text('Try again'));
      await settle(tester);

      expect(cubit.state.stage, SessionStage.ready);
    });

    testWidgets('lets the user sign out when loading fails', (tester) async {
      backend.offline = true;
      final cubit = await pump(tester);
      await tester.runAsync(cubit.loadWorkspaces);
      await tester.pump();

      await tester.tap(find.text('Sign out'));
      await settle(tester);

      expect(cubit.state.stage, SessionStage.signedOut);
    });
  });
}
