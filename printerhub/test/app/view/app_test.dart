import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/gallery/gallery.dart';
import 'package:printerhub/theme/theme.dart';

import '../../helpers/helpers.dart';

void main() {
  group('App', () {
    AppColors? coloursOf(WidgetTester tester, Type screen) {
      return Theme.of(tester.element(find.byType(screen)))
          .extension<AppColors>();
    }

    testWidgets('opens on the gallery in the default theme', (tester) async {
      await tester.pumpWidget(App(preferencesRepository: emptyPreferences()));
      await tester.pumpAndSettle();

      expect(find.byType(GalleryPage), findsOneWidget);
      expect(coloursOf(tester, GalleryPage), AppTheme.volt.light.colors);
    });

    testWidgets('opens in the theme chosen on an earlier launch', (
      tester,
    ) async {
      await tester.pumpWidget(
        App(preferencesRepository: emptyPreferences(themeName: 'mint')),
      );
      await tester.pumpAndSettle();

      expect(coloursOf(tester, GalleryPage), AppTheme.mint.light.colors);
    });

    testWidgets('changes theme from the theme screen and keeps it', (
      tester,
    ) async {
      final preferences = emptyPreferences();
      await tester.pumpWidget(App(preferencesRepository: preferences));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Change theme'));
      await tester.pumpAndSettle();
      expect(find.byType(ThemePage), findsOneWidget);

      await tester.tap(find.text('Indigo'));
      await tester.pumpAndSettle();
      expect(coloursOf(tester, ThemePage), AppTheme.indigo.light.colors);
      verify(() => preferences.saveThemeName('indigo')).called(1);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(GalleryPage), findsOneWidget);
      expect(coloursOf(tester, GalleryPage), AppTheme.indigo.light.colors);
    });

    testWidgets('is named PrinterHub', (tester) async {
      await tester.pumpWidget(App(preferencesRepository: emptyPreferences()));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Title>(find.byType(Title).first).title,
        'PrinterHub',
      );
    });
  });
}
