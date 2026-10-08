import 'package:api_client/testing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/session/session.dart';
import 'package:printerhub/workspace/workspace.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;
  late MockGoRouter router;

  setUp(() {
    backend = TestBackend()..receivedInvitations = [receivedInvitationBody()];
    router = recordingRouter();
  });
  tearDown(() => backend.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.runAsync(backend.signedInBefore);
    await tester.pumpApp(
      const InvitationsPage(),
      backend: backend,
      router: router,
    );
    await tester.pumpAndSettle();
  }

  SessionCubit session(WidgetTester tester) => BlocProvider.of<SessionCubit>(
    tester.element(find.byType(InvitationsView)),
  );

  group('InvitationsPage', () {
    testWidgets('lists the invitations, and joins one', (tester) async {
      await pump(tester);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('You would join as Member'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Join'));
      await tester.pumpAndSettle();

      expect(find.text('You joined Beta'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Join'), findsNothing);
      // The new workspace is the one in use.
      expect(session(tester).state.organization!.name, 'Beta');
      expect(session(tester).state.organizations, hasLength(2));
    });

    testWidgets('says when nobody has invited the person', (tester) async {
      backend.receivedInvitations = [];

      await pump(tester);

      expect(find.text('Nobody has invited you just now.'), findsOneWidget);
      expect(find.text('Have a code?'), findsOneWidget);
    });

    testWidgets('joins by a code', (tester) async {
      await pump(tester);
      final join = find.widgetWithText(OutlinedButton, 'Join with the code');
      expect(tester.widget<OutlinedButton>(join).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'code-invitation-9');
      await tester.pump();
      await tester.ensureVisible(join);
      await tester.tap(join);
      await tester.pumpAndSettle();

      expect(find.text('You joined Beta'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });

    testWidgets('says why a code did not work', (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'wrong');
      await tester.pump();
      await tester.tap(find.text('Join with the code'));
      await tester.pumpAndSettle();

      expect(find.text('That invitation is no longer open.'), findsOneWidget);
    });

    testWidgets('asks an unverified person to verify, and still takes a '
        'code', (tester) async {
      backend.fail('GET /invitations', 403, 'auth.email_not_verified');
      await pump(tester);

      expect(find.textContaining('Verify your email address to see'), findsOne);
      expect(find.text('Invitation code'), findsOneWidget);

      await tester.tap(find.text('Verify your email'));
      verify(() => router.push<Object?>(AppRoutes.verifyEmail)).called(1);
    });

    testWidgets('says why the invitations cannot be read, and tries again', (
      tester,
    ) async {
      await tester.runAsync(backend.signedInBefore);
      backend.offline = true;
      await tester.pumpApp(const InvitationsPage(), backend: backend);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.text('Your invitations could not be read'), findsOneWidget);

      backend.offline = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Beta'), findsOneWidget);
    });
  });
}
