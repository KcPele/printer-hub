import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final volt = AppTheme.volt.light;
  final indigo = AppTheme.indigo.light;

  group('AppColors', () {
    test('copyWith replaces only what is given', () {
      const red = Color(0xFFFF0000);
      final copy = volt.colors.copyWith(primary: red);

      expect(copy.primary, red);
      expect(copy.copyWith(primary: volt.colors.primary), volt.colors);
      expect(volt.colors.copyWith(), volt.colors);
    });

    test('lerp moves from one theme to the other', () {
      expect(volt.colors.lerp(indigo.colors, 0), volt.colors);
      expect(volt.colors.lerp(indigo.colors, 1), indigo.colors);
      expect(volt.colors.lerp(null, 0.5), volt.colors);
    });

    test('equal values are equal', () {
      expect(volt.colors, isNot(indigo.colors));
      expect(volt.colors.copyWith().hashCode, volt.colors.hashCode);
    });
  });

  group('AppSemanticColors', () {
    const semantic = AppSemanticColors.light;

    test('has a tone for every status', () {
      expect(semantic.status(AppStatus.success), semantic.success);
      expect(semantic.status(AppStatus.warning), semantic.warning);
      expect(semantic.status(AppStatus.error), semantic.error);
      expect(semantic.status(AppStatus.info), semantic.info);
      expect(semantic.status(AppStatus.neutral), semantic.neutral);
    });

    test('has a colour for every toner', () {
      expect(semantic.toner(TonerColor.cyan), semantic.tonerCyan);
      expect(semantic.toner(TonerColor.magenta), semantic.tonerMagenta);
      expect(semantic.toner(TonerColor.yellow), semantic.tonerYellow);
      expect(semantic.toner(TonerColor.black), semantic.tonerBlack);
    });

    test('copyWith replaces only what is given', () {
      const black = Color(0xFF000000);
      final copy = semantic.copyWith(tonerBlack: black);

      expect(copy.tonerBlack, black);
      expect(copy.tonerCyan, semantic.tonerCyan);
      expect(semantic.copyWith().success, semantic.success);
    });

    test('lerp moves every colour', () {
      const black = Color(0xFF000000);
      const other = AppSemanticColors(
        success: StatusTone(foreground: black, container: black),
        warning: StatusTone(foreground: black, container: black),
        error: StatusTone(foreground: black, container: black),
        info: StatusTone(foreground: black, container: black),
        neutral: StatusTone(foreground: black, container: black),
        tonerCyan: black,
        tonerMagenta: black,
        tonerYellow: black,
        tonerBlack: black,
      );
      final end = semantic.lerp(other, 1);

      expect(end.success.foreground, black);
      expect(end.neutral.container, black);
      expect(end.tonerCyan, black);
      expect(semantic.lerp(null, 0.5), semantic);
    });

    test('is the same in every theme', () {
      for (final theme in AppTheme.all) {
        expect(theme.light.semantic, AppSemanticColors.light);
      }
    });
  });

  group('AppShapes', () {
    const shapes = AppShapes(
      button: 10,
      card: 20,
      field: 30,
      chip: 40,
      sheet: 50,
    );

    test('exposes each radius as a border radius', () {
      expect(shapes.buttonRadius, BorderRadius.circular(10));
      expect(shapes.cardRadius, BorderRadius.circular(20));
      expect(shapes.fieldRadius, BorderRadius.circular(30));
      expect(shapes.chipRadius, BorderRadius.circular(40));
      expect(
        shapes.sheetRadius,
        const BorderRadius.vertical(top: Radius.circular(50)),
      );
    });

    test('copyWith replaces only what is given', () {
      final copy = shapes.copyWith(card: 1);

      expect(copy.card, 1);
      expect(copy.button, 10);
      expect(shapes.copyWith().sheet, 50);
    });

    test('lerp moves every radius', () {
      const other = AppShapes(button: 0, card: 0, field: 0, chip: 0, sheet: 0);
      final half = shapes.lerp(other, 0.5);

      expect(half.button, 5);
      expect(half.card, 10);
      expect(half.field, 15);
      expect(half.chip, 20);
      expect(half.sheet, 25);
      expect(shapes.lerp(null, 0.5), shapes);
    });
  });

  group('AppDepth', () {
    const border = BorderSide();
    const shadow = BoxShadow(blurRadius: 10);

    test('copyWith replaces only what is given', () {
      final copy = AppDepth.flat.copyWith(cardBorder: border);

      expect(copy.cardBorder, border);
      expect(copy.cardShadow, isEmpty);
      expect(AppDepth.flat.copyWith(cardShadow: [shadow]).cardShadow, [shadow]);
    });

    test('lerp moves the shadow and the border', () {
      const raised = AppDepth(cardShadow: [shadow], cardBorder: border);
      final end = AppDepth.flat.lerp(raised, 1);

      expect(end.cardShadow.single.blurRadius, 10);
      expect(end.cardBorder.width, border.width);
      expect(AppDepth.flat.lerp(null, 0.5), AppDepth.flat);
    });
  });
}
