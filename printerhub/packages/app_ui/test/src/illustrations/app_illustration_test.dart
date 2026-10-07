import 'package:app_ui/app_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group('IllustrationColorMapper', () {
    final colors = AppTheme.volt.light.colors;
    final mapper = IllustrationColorMapper(colors);

    Color map(int rgb, {int alpha = 0xFF}) {
      return mapper.substitute(null, 'path', 'fill', Color(alpha << 24 | rgb));
    }

    test('replaces every placeholder with its theme token', () {
      expect(map(IllustrationPalette.primary), colors.primary);
      expect(map(IllustrationPalette.onPrimary), colors.onPrimary);
      expect(map(IllustrationPalette.emphasis), colors.emphasis);
      expect(map(IllustrationPalette.accent), colors.accent);
      expect(map(IllustrationPalette.ink), colors.inverseSurface);
      expect(map(IllustrationPalette.onInk), colors.onInverseSurface);
      expect(map(IllustrationPalette.surface), colors.surface);
      expect(map(IllustrationPalette.surfaceMuted), colors.surfaceMuted);
      expect(map(IllustrationPalette.outline), colors.outline);
      expect(map(IllustrationPalette.textMuted), colors.textMuted);
    });

    test('keeps a colour that is not a placeholder', () {
      const green = Color(0xFF3DDC84);
      expect(mapper.substitute(null, 'circle', 'fill', green), green);
    });

    test('keeps the transparency the file was drawn with', () {
      final mapped = map(IllustrationPalette.ink, alpha: 0x80);

      expect(mapped.a, closeTo(0x80 / 0xFF, 0.001));
      expect(mapped.withValues(alpha: 1), colors.inverseSurface);
    });

    test('is equal for equal colours, so parsed pictures are reused', () {
      expect(mapper, IllustrationColorMapper(colors.copyWith()));
      expect(mapper.hashCode, IllustrationColorMapper(colors).hashCode);
      expect(
        mapper,
        isNot(IllustrationColorMapper(AppTheme.mint.light.colors)),
      );
    });
  });

  group('AppIllustration', () {
    testWidgets('draws every illustration in every theme', (tester) async {
      for (final theme in AppTheme.all) {
        for (final illustration in AppIllustrations.values) {
          await tester.pumpThemed(
            AppIllustration(illustration, width: 120),
            theme: theme,
          );
          await tester.pumpAndSettle();

          expect(find.byType(SvgPicture), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets('is hidden from screen readers without a label', (
      tester,
    ) async {
      await tester.pumpThemed(const AppIllustration(AppIllustrations.printer));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('A printer'), findsNothing);
    });

    testWidgets('is announced by its label', (tester) async {
      await tester.pumpThemed(
        const AppIllustration(
          AppIllustrations.printer,
          semanticLabel: 'A printer',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('A printer'), findsOneWidget);
    });
  });
}
