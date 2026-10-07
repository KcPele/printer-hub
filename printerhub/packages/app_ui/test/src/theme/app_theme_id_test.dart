import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppThemeId.fromName', () {
    test('reads every theme by its name', () {
      for (final id in AppThemeId.values) {
        expect(AppThemeId.fromName(id.name), id);
      }
    });

    test('falls back when the name is missing or unknown', () {
      expect(AppThemeId.fromName(null), AppThemeId.fallback);
      expect(AppThemeId.fromName('neon'), AppThemeId.fallback);
    });
  });
}
