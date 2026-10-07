import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppThemePreview', () {
    Future<void> pump(
      WidgetTester tester, {
      required bool selected,
      AppTheme preview = AppTheme.mint,
      VoidCallback? onTap,
    }) {
      return tester.pumpThemed(
        SizedBox(
          width: 110,
          child: AppThemePreview(
            theme: preview,
            label: 'Mint',
            selected: selected,
            onTap: onTap,
          ),
        ),
      );
    }

    testWidgets('marks the selected theme', (tester) async {
      await pump(tester, selected: true);

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(AppThemePreview)),
        isSemantics(
          label: 'Mint',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
        ),
      );
    });

    testWidgets('does not mark an unselected theme', (tester) async {
      await pump(tester, selected: false);

      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.text('Mint'), findsOneWidget);
    });

    testWidgets('draws the miniature in the previewed theme', (tester) async {
      for (final preview in AppTheme.all) {
        await pump(tester, selected: false, preview: preview);
        await tester.pumpAndSettle();

        final fills = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(AppThemePreview),
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((box) => (box.decoration as BoxDecoration).color);

        expect(
          fills,
          containsAll(<Color>[
            preview.light.colors.background,
            preview.light.colors.surface,
            preview.light.colors.primary,
          ]),
        );
      }
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var taps = 0;
      await pump(tester, selected: false, onTap: () => taps++);

      await tester.tap(find.byType(AppThemePreview));

      expect(taps, 1);
    });
  });
}
