import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/auth/auth.dart';

import '../../helpers/helpers.dart';

void main() {
  group('RegisterPage', () {
    late TestBackend backend;

    setUp(() => backend = TestBackend());
    tearDown(() => backend.close());

    Future<void> pump(WidgetTester tester, {MockGoRouter? router}) {
      return tester.pumpApp(
        const RegisterPage(),
        backend: backend,
        router: router,
      );
    }

    testWidgets('checks every field before sending', (tester) async {
      await pump(tester);
      await tester.fill('Password', 'short');

      await tester.tap(find.text('Create account'));
      await tester.pump();

      expect(find.text('Enter your name.'), findsOneWidget);
      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      expect(backend.network.requests, isEmpty);
    });

    testWidgets('creates the account and signs in', (tester) async {
      await pump(tester);
      await tester.fill('Your name', ' Grace Hopper ');
      await tester.fill('Email', 'grace@example.com');
      await tester.fill('Password', 'long enough');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(backend.lastBody('POST /auth/register'), {
        'name': 'Grace Hopper',
        'email': 'grace@example.com',
        'password': 'long enough',
      });
      expect(backend.auth.user?.name, 'Grace Hopper');
    });

    testWidgets('says when the email already has an account', (tester) async {
      backend.fail('POST /auth/register', 409, 'auth.email_taken');
      await pump(tester);
      await tester.fill('Your name', 'Grace');
      await tester.fill('Email', 'grace@example.com');
      await tester.fill('Password', 'long enough');

      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('already an account with that email'),
        findsOneWidget,
      );
    });

    testWidgets('leads back to sign-in', (tester) async {
      final router = recordingRouter();
      await pump(tester, router: router);

      await tester.ensureVisible(find.text('Already have an account? Sign in'));
      await tester.tap(find.text('Already have an account? Sign in'));

      verify(() => router.go(AppRoutes.signIn)).called(1);
    });
  });
}
