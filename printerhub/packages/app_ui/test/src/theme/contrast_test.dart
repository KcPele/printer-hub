import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

/// WCAG AA for normal text.
const double _aa = 4.5;

void main() {
  for (final theme in AppTheme.all) {
    final colors = theme.light.colors;
    final semantic = theme.light.semantic;

    group('${theme.id.name} meets AA contrast for', () {
      void check(String name, Color foreground, Color background) {
        test(name, () {
          expect(
            contrast(foreground, background),
            greaterThanOrEqualTo(_aa),
            reason: '$foreground on $background',
          );
        });
      }

      for (final (name, fill) in [
        ('background', colors.background),
        ('surface', colors.surface),
        ('muted surface', colors.surfaceMuted),
      ]) {
        check('text on the $name', colors.text, fill);
        check('supporting text on the $name', colors.textMuted, fill);
        check('emphasis on the $name', colors.emphasis, fill);

        for (final status in AppStatus.values) {
          check(
            '${status.name} status on the $name',
            semantic.status(status).foreground,
            fill,
          );
        }
      }

      check('text on the primary fill', colors.onPrimary, colors.primary);
      check('text on the emphasis fill', colors.onEmphasis, colors.emphasis);
      check('text on the accent fill', colors.onAccent, colors.accent);
      check(
        'text on the inverse surface',
        colors.onInverseSurface,
        colors.inverseSurface,
      );

      for (final status in AppStatus.values) {
        final tone = semantic.status(status);
        check(
          '${status.name} status on its container',
          tone.foreground,
          tone.container,
        );
      }

      for (final (tone, foreground, fill) in [
        (AppCardTone.inverse, colors.onInverseSurface, colors.inverseSurface),
        (AppCardTone.primary, colors.onPrimary, colors.primary),
      ]) {
        check(
          'supporting text on a ${tone.name} card',
          Color.lerp(foreground, fill, AppCard.mutedBlend(tone))!,
          fill,
        );
      }
    });
  }
}
