import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppCard', () {
    BoxDecoration decorationOf(WidgetTester tester) {
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(AppCard),
          matching: find.byType(DecoratedBox),
        ),
      );
      return box.decoration as BoxDecoration;
    }

    testWidgets('takes its shape and depth from each theme', (tester) async {
      for (final theme in AppTheme.all) {
        final tokens = theme.light;
        await tester.pumpThemed(
          const AppCard(child: Text('Office')),
          theme: theme,
        );
        await tester.pumpAndSettle();

        final decoration = decorationOf(tester);
        expect(decoration.color, tokens.colors.surface);
        expect(decoration.borderRadius, tokens.shapes.cardRadius);
        expect(decoration.boxShadow, tokens.depth.cardShadow);
        expect(
          decoration.border,
          tokens.depth.cardBorder.style == BorderStyle.none
              ? isNull
              : Border.fromBorderSide(tokens.depth.cardBorder),
        );
      }
    });

    testWidgets('leaves the shadow and border off a toned card', (
      tester,
    ) async {
      for (final theme in [AppTheme.indigo, AppTheme.mint]) {
        await tester.pumpThemed(
          const AppCard(tone: AppCardTone.muted, child: Text('Office')),
          theme: theme,
        );
        await tester.pumpAndSettle();

        final decoration = decorationOf(tester);
        expect(decoration.color, theme.light.colors.surfaceMuted);
        expect(decoration.boxShadow, isNull);
        expect(decoration.border, isNull);
      }
    });

    for (final theme in AppTheme.all) {
      final colors = theme.light.colors;

      for (final (tone, fill, foreground) in [
        (AppCardTone.inverse, colors.inverseSurface, colors.onInverseSurface),
        (AppCardTone.primary, colors.primary, colors.onPrimary),
      ]) {
        testWidgets('gives children readable colours on ${tone.name} in '
            '${theme.id.name}', (tester) async {
          late AppColors inside;
          late TextStyle title;
          late IconThemeData icons;

          await tester.pumpThemed(
            AppCard(
              tone: tone,
              child: Builder(
                builder: (context) {
                  inside = context.colors;
                  title = context.textTheme.titleLarge!;
                  icons = IconTheme.of(context);
                  return const Text('Office');
                },
              ),
            ),
            theme: theme,
          );
          await tester.pumpAndSettle();

          expect(decorationOf(tester).color, fill);
          expect(inside.text, foreground);
          expect(inside.surface, fill);
          expect(title.color, foreground);
          expect(icons.color, foreground);
          expect(contrast(inside.textMuted, fill), greaterThanOrEqualTo(4.5));
        });
      }
    }

    testWidgets('calls onTap when tapped', (tester) async {
      var taps = 0;
      await tester.pumpThemed(
        AppCard(onTap: () => taps++, child: const Text('Office')),
      );

      await tester.tap(find.text('Office'));

      expect(taps, 1);
    });
  });
}
