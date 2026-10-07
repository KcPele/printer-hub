import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/home/home.dart';

import '../../helpers/helpers.dart';

void main() {
  group('HomePage', () {
    late TestBackend backend;

    setUp(() => backend = TestBackend());
    tearDown(() => backend.close());

    testWidgets('tells a new user what the app is for and how to begin', (
      tester,
    ) async {
      await tester.pumpApp(const HomePage(), backend: backend);
      await tester.pumpAndSettle();

      expect(find.text('PrinterHub'), findsOneWidget);
      expect(find.byType(AppIllustration), findsOneWidget);
      expect(find.text('Find a printer, tap it, use it'), findsOneWidget);
      expect(find.byType(AppNotice), findsNothing);

      await tester.scrollUntilVisible(find.text('Follow every job'), 200);
      expect(find.text('Getting started'), findsOneWidget);
      expect(find.text('Add a printer'), findsOneWidget);
      expect(find.text('Print or scan'), findsOneWidget);
      for (final number in ['1', '2', '3']) {
        expect(find.text(number), findsOneWidget);
      }
    });

    testWidgets('reminds an unverified user to verify their email', (
      tester,
    ) async {
      final router = recordingRouter();
      await tester.runAsync(backend.signedInBefore);
      await tester.pumpApp(const HomePage(), backend: backend, router: router);
      await tester.pumpAndSettle();

      expect(find.byType(AppNotice), findsOneWidget);
      await tester.tap(find.text('Verify your email'));

      verify(() => router.push<Object?>(AppRoutes.verifyEmail)).called(1);
    });

    testWidgets('has no reminder for a verified user', (tester) async {
      backend.user = {
        ...backend.user,
        'email_verified_at': '2026-10-07T11:00:00Z',
      };
      await tester.runAsync(backend.signedInBefore);
      await tester.pumpApp(const HomePage(), backend: backend);
      await tester.pumpAndSettle();

      expect(find.byType(AppNotice), findsNothing);
    });
  });
}
