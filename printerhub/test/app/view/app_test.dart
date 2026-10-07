import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/activity/activity.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/gallery/gallery.dart';
import 'package:printerhub/home/home.dart';
import 'package:printerhub/printers/printers.dart';
import 'package:printerhub/settings/settings.dart';
import 'package:printerhub/theme/theme.dart';
import 'package:printerhub/welcome/welcome.dart';

import '../../helpers/helpers.dart';

void main() {
  group('App', () {
    AppColors? coloursOf(WidgetTester tester, Type screen) {
      return Theme.of(tester.element(find.byType(screen)))
          .extension<AppColors>();
    }

    Future<MockPreferencesRepository> pump(
      WidgetTester tester, {
      String? themeName,
      bool welcomed = true,
    }) async {
      final preferences = emptyPreferences(
        themeName: themeName,
        onboardingCompleted: welcomed,
      );
      await tester.pumpWidget(App(preferencesRepository: preferences));
      await tester.pumpAndSettle();
      return preferences;
    }

    Future<void> openArea(WidgetTester tester, String label) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('is named PrinterHub', (tester) async {
      await pump(tester);

      expect(
        tester.widget<Title>(find.byType(Title).first).title,
        'PrinterHub',
      );
    });

    group('on a new install', () {
      testWidgets('opens on the welcome screens', (tester) async {
        await pump(tester, welcomed: false);

        expect(find.byType(WelcomePage), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
      });

      testWidgets('enters the app after the welcome screens', (tester) async {
        final preferences = await pump(tester, welcomed: false);

        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();

        expect(find.byType(HomePage), findsOneWidget);
        expect(find.byType(WelcomePage), findsNothing);
        verify(preferences.completeOnboarding).called(1);
      });
    });

    group('once the welcome screens were seen', () {
      testWidgets('opens on Home in the default theme', (tester) async {
        await pump(tester);

        expect(find.byType(HomePage), findsOneWidget);
        expect(find.byType(WelcomePage), findsNothing);
        expect(coloursOf(tester, HomePage), AppTheme.volt.light.colors);
      });

      testWidgets('opens in the theme chosen on an earlier launch', (
        tester,
      ) async {
        await pump(tester, themeName: 'mint');

        expect(coloursOf(tester, HomePage), AppTheme.mint.light.colors);
      });

      testWidgets('moves between the four areas', (tester) async {
        await pump(tester);

        await openArea(tester, 'Printers');
        expect(find.byType(PrintersPage), findsOneWidget);

        await openArea(tester, 'Activity');
        expect(find.byType(ActivityPage), findsOneWidget);

        await openArea(tester, 'Settings');
        expect(find.byType(SettingsPage), findsOneWidget);

        await openArea(tester, 'Home');
        expect(find.byType(HomePage), findsOneWidget);
      });

      testWidgets('changes theme in Settings and keeps it', (tester) async {
        final preferences = await pump(tester);

        await openArea(tester, 'Settings');
        await tester.tap(find.text('Theme'));
        await tester.pumpAndSettle();
        expect(find.byType(ThemePage), findsOneWidget);

        await tester.tap(find.text('Indigo'));
        await tester.pumpAndSettle();
        expect(coloursOf(tester, ThemePage), AppTheme.indigo.light.colors);
        verify(() => preferences.saveThemeName('indigo')).called(1);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(SettingsPage), findsOneWidget);
        expect(find.text('Indigo'), findsOneWidget);

        await openArea(tester, 'Home');
        expect(coloursOf(tester, HomePage), AppTheme.indigo.light.colors);
      });

      testWidgets(
        'returns to the top of an area when its tab is tapped again',
        (tester) async {
          await pump(tester);
          await openArea(tester, 'Settings');
          await tester.tap(find.text('Design gallery'));
          await tester.pumpAndSettle();
          expect(find.byType(GalleryPage), findsOneWidget);

          await openArea(tester, 'Settings');

          expect(find.byType(GalleryPage), findsNothing);
          expect(find.byType(SettingsPage), findsOneWidget);
        },
      );

      testWidgets('keeps the place in an area while visiting another', (
        tester,
      ) async {
        await pump(tester);
        await openArea(tester, 'Settings');
        await tester.tap(find.text('Theme'));
        await tester.pumpAndSettle();

        await openArea(tester, 'Home');
        await openArea(tester, 'Settings');

        expect(find.byType(ThemePage), findsOneWidget);
      });
    });
  });
}
