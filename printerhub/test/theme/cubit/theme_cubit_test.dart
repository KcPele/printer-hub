import 'package:app_ui/app_ui.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/theme/theme.dart';

import '../../helpers/helpers.dart';

void main() {
  group('ThemeCubit', () {
    late MockPreferencesRepository preferences;

    setUp(() => preferences = emptyPreferences());

    test('starts with the default theme on a new install', () {
      expect(
        ThemeCubit(preferencesRepository: preferences).state,
        AppThemeId.fallback,
      );
    });

    test('starts with the theme chosen before', () {
      expect(
        ThemeCubit(preferencesRepository: emptyPreferences(themeName: 'mint'))
            .state,
        AppThemeId.mint,
      );
    });

    blocTest<ThemeCubit, AppThemeId>(
      'applies and saves a new theme',
      build: () => ThemeCubit(preferencesRepository: preferences),
      act: (cubit) => cubit.select(AppThemeId.indigo),
      expect: () => [AppThemeId.indigo],
      verify: (_) {
        verify(() => preferences.saveThemeName('indigo')).called(1);
      },
    );

    blocTest<ThemeCubit, AppThemeId>(
      'does nothing when the theme is already applied',
      build: () => ThemeCubit(preferencesRepository: preferences),
      act: (cubit) => cubit.select(AppThemeId.fallback),
      expect: () => <AppThemeId>[],
      verify: (_) {
        verifyNever(() => preferences.saveThemeName(any()));
      },
    );
  });
}
