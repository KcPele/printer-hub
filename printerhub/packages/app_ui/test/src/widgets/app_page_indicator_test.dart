import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppPageIndicator', () {
    List<AnimatedContainer> dots(WidgetTester tester) {
      return tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .toList();
    }

    Color? colourOf(AnimatedContainer dot) {
      return (dot.decoration! as BoxDecoration).color;
    }

    testWidgets('draws one dot per page and marks the current one', (
      tester,
    ) async {
      for (final theme in AppTheme.all) {
        final colors = theme.light.colors;
        await tester.pumpThemed(
          const AppPageIndicator(count: 4, index: 2),
          theme: theme,
        );
        await tester.pumpAndSettle();

        final all = dots(tester);
        expect(all, hasLength(4));
        expect(colourOf(all[2]), colors.emphasis);
        expect(colourOf(all[0]), colors.outline);
        expect(
          tester.getSize(find.byWidget(all[2])).width,
          greaterThan(tester.getSize(find.byWidget(all[0])).width),
        );
      }
    });

    testWidgets('moves the mark when the page changes', (tester) async {
      await tester.pumpThemed(const AppPageIndicator(count: 3, index: 0));
      await tester.pumpThemed(const AppPageIndicator(count: 3, index: 1));
      await tester.pumpAndSettle();

      final colors = AppTheme.volt.light.colors;
      expect(colourOf(dots(tester)[0]), colors.outline);
      expect(colourOf(dots(tester)[1]), colors.emphasis);
    });
  });
}
