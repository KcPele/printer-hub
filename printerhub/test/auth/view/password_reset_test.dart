import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/auth/auth.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;
  late MockGoRouter router;

  setUp(() {
    backend = TestBackend();
    router = recordingRouter();
  });
  tearDown(() => backend.close());

  group('ForgotPasswordPage', () {
    Future<void> pump(WidgetTester tester) {
      return tester.pumpApp(
        const ForgotPasswordPage(),
        backend: backend,
        router: router,
      );
    }

    testWidgets('needs an email address', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Send code'));
      await tester.pump();

      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(backend.network.requests, isEmpty);
    });

    testWidgets('sends the code and moves on with the address', (tester) async {
      await pump(tester);
      await tester.fill('Email', 'ada@example.com');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(backend.lastBody('POST /auth/password/forgot'), {
        'email': 'ada@example.com',
      });
      verify(
        () => router.push<Object?>(
          AppRoutes.resetPassword,
          extra: 'ada@example.com',
        ),
      ).called(1);
    });

    testWidgets('says when too many codes were requested', (tester) async {
      backend.fail('POST /auth/password/forgot', 429, 'rate_limited');
      await pump(tester);
      await tester.fill('Email', 'ada@example.com');

      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Too many attempts'), findsOneWidget);
      verifyNever(
        () => router.push<Object?>(any(), extra: any(named: 'extra')),
      );
    });
  });

  group('ResetPasswordPage', () {
    Future<void> pump(WidgetTester tester) {
      return tester.pumpApp(
        const ResetPasswordPage(email: 'ada@example.com'),
        backend: backend,
        router: router,
      );
    }

    testWidgets('says where the code went', (tester) async {
      await pump(tester);

      expect(
        find.text('Enter the code we sent to ada@example.com.'),
        findsOneWidget,
      );
    });

    testWidgets('needs six digits and a long enough password', (tester) async {
      await pump(tester);
      await tester.fill('6-digit code', '12ab');
      await tester.fill('New password', 'short');

      await tester.tap(find.text('Change password'));
      await tester.pump();

      // Letters are not accepted into the code at all.
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Enter the 6 digits from the email.'), findsOneWidget);
      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      expect(backend.network.requests, isEmpty);
    });

    testWidgets('changes the password and returns to sign-in', (tester) async {
      await pump(tester);
      await tester.fill('6-digit code', '123456');
      await tester.fill('New password', 'new password');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(backend.lastBody('POST /auth/password/reset'), {
        'email': 'ada@example.com',
        'code': '123456',
        'new_password': 'new password',
      });
      expect(
        find.text('Password changed. Sign in with the new one.'),
        findsOneWidget,
      );
      verify(() => router.go(AppRoutes.signIn)).called(1);
    });

    testWidgets('says when the code is wrong', (tester) async {
      backend.fail('POST /auth/password/reset', 400, 'auth.code_invalid');
      await pump(tester);
      await tester.fill('6-digit code', '000000');
      await tester.fill('New password', 'new password');

      await tester.tap(find.text('Change password'));
      await tester.pumpAndSettle();

      expect(find.textContaining('wrong or has expired'), findsOneWidget);
      verifyNever(() => router.go(any()));
    });
  });
}
