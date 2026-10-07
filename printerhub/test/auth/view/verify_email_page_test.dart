import 'dart:async';

import 'package:api_client/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/auth/auth.dart';

import '../../helpers/helpers.dart';

void main() {
  group('VerifyEmailPage', () {
    late TestBackend backend;
    late MockGoRouter router;

    setUp(() async {
      backend = TestBackend();
      router = recordingRouter();
      await backend.signedInBefore();
    });
    tearDown(() => backend.close());

    Future<void> pump(WidgetTester tester) {
      return tester.pumpApp(
        const VerifyEmailPage(),
        backend: backend,
        router: router,
      );
    }

    testWidgets('says where the code went', (tester) async {
      await pump(tester);

      expect(
        find.text('Enter the 6-digit code we sent to ada@example.com.'),
        findsOneWidget,
      );
    });

    testWidgets('needs six digits', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Verify'));
      await tester.pump();

      expect(find.text('Enter the 6 digits from the email.'), findsOneWidget);
      expect(backend.network.requests, isEmpty);
    });

    testWidgets('verifies the address and goes back', (tester) async {
      await pump(tester);
      await tester.fill('6-digit code', '123456');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(backend.auth.user?.emailVerified, isTrue);
      expect(find.text('Email verified.'), findsOneWidget);
      verify(router.pop).called(1);
    });

    testWidgets('says when the code is wrong', (tester) async {
      backend.fail('POST /auth/email/verify', 400, 'auth.code_invalid');
      await pump(tester);
      await tester.fill('6-digit code', '000000');

      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      expect(find.textContaining('wrong or has expired'), findsOneWidget);
      verifyNever(router.pop);
    });

    testWidgets('sends a new code', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Send a new code'));
      await tester.pumpAndSettle();

      expect(backend.sent('POST /auth/email/resend'), hasLength(1));
      expect(find.text('A new code is on its way.'), findsOneWidget);
    });

    testWidgets('says when a new code could not be sent', (tester) async {
      backend.fail('POST /auth/email/resend', 429, 'rate_limited');
      await pump(tester);

      await tester.tap(find.text('Send a new code'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Too many attempts'), findsOneWidget);
    });

    testWidgets('cannot ask twice while a request is out', (tester) async {
      final gate = Completer<void>();
      backend.routes['POST /auth/email/resend'] = (_) async {
        await gate.future;
        return const FakeResponse(204);
      };
      await pump(tester);

      await tester.tap(find.text('Send a new code'));
      await tester.pump();

      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Send a new code'),
      );
      expect(button.onPressed, isNull);

      gate.complete();
      await tester.pumpAndSettle();
    });
  });
}
