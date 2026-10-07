import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/auth/auth.dart';

import '../../helpers/helpers.dart';

void main() {
  group('SignInPage', () {
    late TestBackend backend;

    setUp(() => backend = TestBackend());
    tearDown(() => backend.close());

    Future<void> pump(WidgetTester tester, {MockGoRouter? router}) {
      return tester.pumpApp(
        const SignInPage(),
        backend: backend,
        router: router,
      );
    }

    Future<void> fillAndSubmit(WidgetTester tester) async {
      await tester.fill('Email', ' ada@example.com ');
      await tester.fill('Password', 'correct horse');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
    }

    testWidgets('asks for an email and a password', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Sign in'));
      await tester.pump();

      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(backend.network.requests, isEmpty);
    });

    testWidgets('signs in', (tester) async {
      await pump(tester);

      await fillAndSubmit(tester);

      expect(backend.auth.user?.email, 'ada@example.com');
      expect(backend.lastBody('POST /auth/login'), {
        'email': 'ada@example.com',
        'password': 'correct horse',
      });
    });

    testWidgets('signs in from the keyboard', (tester) async {
      await pump(tester);
      await tester.fill('Email', 'ada@example.com');
      await tester.fill('Password', 'correct horse');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(backend.auth.user, isNotNull);
    });

    testWidgets('says why signing in failed', (tester) async {
      backend.fail('POST /auth/login', 401, 'auth.invalid_credentials');
      await pump(tester);

      await fillAndSubmit(tester);

      expect(find.byType(AppNotice), findsOneWidget);
      expect(find.text("That email and password don't match."), findsOneWidget);
      expect(backend.auth.user, isNull);
    });

    testWidgets('says when the API cannot be reached', (tester) async {
      backend.offline = true;
      await pump(tester);

      await fillAndSubmit(tester);

      expect(find.textContaining("Can't reach PrinterHub"), findsOneWidget);
    });

    testWidgets('leads to password reset and to registration', (tester) async {
      final router = recordingRouter();
      await pump(tester, router: router);

      await tester.tap(find.text('Forgot password?'));
      await tester.tap(find.text('New here? Create an account'));

      verify(() => router.push<Object?>(AppRoutes.forgotPassword)).called(1);
      verify(() => router.push<Object?>(AppRoutes.register)).called(1);
    });
  });
}
