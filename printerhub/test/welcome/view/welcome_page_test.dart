import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/theme/theme.dart';
import 'package:printerhub/welcome/welcome.dart';

import '../../helpers/helpers.dart';

void main() {
  group('WelcomePage', () {
    late MockPreferencesRepository preferences;
    late GoRouter router;

    setUp(() {
      preferences = emptyPreferences();
      router = recordingRouter();
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpApp(
        const WelcomePage(),
        preferencesRepository: preferences,
        router: router,
      );
      await tester.pumpAndSettle();
    }

    Future<void> next(WidgetTester tester) async {
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
    }

    int indicated(WidgetTester tester) {
      return tester
          .widget<AppPageIndicator>(find.byType(AppPageIndicator))
          .index;
    }

    testWidgets('opens on what the app does', (tester) async {
      await pump(tester);

      expect(find.text('Find a printer, tap it, use it'), findsOneWidget);
      expect(find.byType(AppIllustration), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(indicated(tester), 0);
    });

    testWidgets('walks through each introduction', (tester) async {
      await pump(tester);

      await next(tester);
      expect(find.text('Print and scan from your phone'), findsOneWidget);
      expect(indicated(tester), 1);

      await next(tester);
      expect(find.text('Your documents stay with you'), findsOneWidget);
      expect(indicated(tester), 2);
    });

    testWidgets('follows a swipe', (tester) async {
      await pump(tester);

      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();

      expect(find.text('Print and scan from your phone'), findsOneWidget);
      expect(indicated(tester), 1);
    });

    testWidgets('ends with the theme choice', (tester) async {
      await pump(tester);
      for (var i = 0; i < WelcomeCubit.pageCount - 1; i++) {
        await next(tester);
      }

      expect(find.text('Make it yours'), findsOneWidget);
      expect(find.byType(ThemePicker), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
      expect(find.text('Skip').hitTestable(), findsNothing);

      await tester.tap(find.text('Indigo'));
      await tester.pumpAndSettle();
      verify(() => preferences.saveThemeName('indigo')).called(1);
    });

    testWidgets('opens the app from the last screen', (tester) async {
      await pump(tester);
      for (var i = 0; i < WelcomeCubit.pageCount - 1; i++) {
        await next(tester);
      }

      await next(tester);

      verify(preferences.completeOnboarding).called(1);
      verify(() => router.go(AppRoutes.home)).called(1);
    });

    testWidgets('can be skipped', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      verify(preferences.completeOnboarding).called(1);
      verify(() => router.go(AppRoutes.home)).called(1);
    });
  });
}
