import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/gallery/gallery.dart';
import 'package:printerhub/theme/theme.dart';

import '../../helpers/helpers.dart';

void main() {
  group('GalleryPage', () {
    Future<void> scrollTo(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows every shared widget', (tester) async {
      await tester.pumpApp(const GalleryPage());
      await tester.pumpAndSettle();

      expect(find.text('Design gallery'), findsOneWidget);
      expect(find.byType(ThemePicker), findsOneWidget);
      expect(find.byType(AppIllustration), findsOneWidget);
      expect(find.text('Xerox VersaLink C7130'), findsOneWidget);

      await scrollTo(tester, find.text('Jobs waiting'));
      expect(find.text('128'), findsOneWidget);

      await scrollTo(tester, find.text('Offline'));
      expect(find.byType(StatusPill), findsWidgets);

      await scrollTo(tester, find.text('Black'));
      expect(find.byType(SupplyLevelBar), findsNWidgets(4));
      expect(find.text('72%'), findsOneWidget);
      expect(find.text('Unknown'), findsOneWidget);

      await scrollTo(tester, find.text('Last used 4 minutes ago'));
      expect(find.text('Print anything'), findsOneWidget);
    });

    testWidgets('redraws in the theme that is picked', (tester) async {
      await tester.pumpApp(const GalleryPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Indigo'));
      await tester.pumpAndSettle();

      expect(
        Theme.of(tester.element(find.byType(GalleryPage)))
            .extension<AppColors>(),
        AppTheme.indigo.light.colors,
      );
    });

    testWidgets('opens the theme screen from the app bar', (tester) async {
      final router = recordingRouter();
      await tester.pumpApp(const GalleryPage(), router: router);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Change theme'));

      verify(() => router.push<Object?>(AppRoutes.theme)).called(1);
    });

    testWidgets('has working sample controls', (tester) async {
      await tester.pumpApp(const GalleryPage());
      await tester.pumpAndSettle();

      // Scrolling to a widget puts it at the top of the list, so each row is
      // brought into view before it is tapped.
      await scrollTo(tester, find.text('Print'));
      await tester.tap(find.text('Print'));
      await tester.tap(find.text('Scan'));
      await scrollTo(tester, find.text('View details'));
      await tester.tap(find.text('View details'));

      await scrollTo(tester, find.text('Print in colour'));
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}
