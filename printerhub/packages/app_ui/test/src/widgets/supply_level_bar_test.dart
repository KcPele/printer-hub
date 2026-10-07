import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group('SupplyLevelBar', () {
    double fillOf(WidgetTester tester) {
      return tester
          .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .widthFactor!;
    }

    Future<void> pump(WidgetTester tester, double? level) {
      return tester.pumpThemed(
        SizedBox(
          width: 200,
          child: SupplyLevelBar(
            toner: TonerColor.cyan,
            label: 'Cyan',
            valueLabel: level == null ? 'Unknown' : '72%',
            level: level,
          ),
        ),
      );
    }

    testWidgets('fills in proportion to the level', (tester) async {
      await pump(tester, 0.72);

      expect(fillOf(tester), 0.72);
      expect(find.text('Cyan'), findsOneWidget);
      expect(find.text('72%'), findsOneWidget);
    });

    testWidgets('is empty when the printer does not report a level', (
      tester,
    ) async {
      await pump(tester, null);

      expect(fillOf(tester), 0);
      expect(find.text('Unknown'), findsOneWidget);
    });

    testWidgets('keeps an out-of-range level inside the track', (tester) async {
      await pump(tester, 1.4);
      expect(fillOf(tester), 1);

      await pump(tester, -0.2);
      expect(fillOf(tester), 0);
    });

    testWidgets('uses the toner colour in every theme', (tester) async {
      for (final theme in AppTheme.all) {
        for (final toner in TonerColor.values) {
          await tester.pumpThemed(
            SizedBox(
              width: 200,
              child: SupplyLevelBar(
                toner: toner,
                label: toner.name,
                valueLabel: '50%',
                level: 0.5,
              ),
            ),
            theme: theme,
          );
          await tester.pumpAndSettle();

          final fill = tester.widget<ColoredBox>(
            find.descendant(
              of: find.byType(FractionallySizedBox),
              matching: find.byType(ColoredBox),
            ),
          );
          expect(fill.color, AppSemanticColors.light.toner(toner));
        }
      }
    });

    testWidgets('draws a supply without a colour in a neutral one', (
      tester,
    ) async {
      await tester.pumpThemed(
        const SizedBox(
          width: 200,
          child: SupplyLevelBar(
            toner: null,
            label: 'Drum',
            valueLabel: '60%',
            level: 0.6,
          ),
        ),
      );

      final fill = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(FractionallySizedBox),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(fill.color, AppTheme.volt.light.colors.textMuted);
    });

    testWidgets('is announced as one item with its level', (tester) async {
      await pump(tester, 0.72);

      expect(find.bySemanticsLabel('Cyan, 72%'), findsOneWidget);
    });
  });
}
