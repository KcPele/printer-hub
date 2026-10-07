import 'package:app_ui/app_ui.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/theme/theme.dart';

import '../../helpers/helpers.dart';

void main() {
  accountTests();

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
        ThemeCubit(preferencesRepository: emptyPreferences(themeName: 'volt'))
            .state,
        AppThemeId.volt,
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

// The theme and the account.
void accountTests() {
  group('ThemeCubit with an account', () {
    late TestBackend backend;

    setUp(() => backend = TestBackend());
    tearDown(() => backend.close());

    ThemeCubit build(MockPreferencesRepository preferences) {
      final cubit = ThemeCubit(
        preferencesRepository: preferences,
        authRepository: backend.auth,
      );
      addTearDown(cubit.close);
      return cubit;
    }

    Map<String, Object?> withTheme(String theme) => {
      ...backend.user,
      'preferences': {
        ...backend.user['preferences']! as Map<String, Object?>,
        'app_theme': theme,
      },
    };

    test('takes the account theme on a device with no choice yet', () async {
      backend.user = withTheme('indigo');
      final preferences = emptyPreferences();
      final cubit = build(preferences);

      await backend.auth.signIn(email: 'ada@example.com', password: 'pw');
      await pumpEventQueue();

      expect(cubit.state, AppThemeId.indigo);
      expect(preferences.themeName, 'indigo');
    });

    test('keeps the theme chosen on this device when signing in', () async {
      backend.user = withTheme('indigo');
      final cubit = build(emptyPreferences(themeName: 'volt'));

      await backend.auth.signIn(email: 'ada@example.com', password: 'pw');
      await pumpEventQueue();

      expect(cubit.state, AppThemeId.volt);
    });

    test('saves a new choice with the account', () async {
      await backend.signedInBefore();
      final cubit = build(emptyPreferences());

      await cubit.select(AppThemeId.volt);

      expect(
        (backend.lastBody('PATCH /users/me')['preferences']
            as Map<String, dynamic>)['app_theme'],
        'volt',
      );
      expect(backend.auth.user?.appTheme, 'volt');
    });

    test(
      'still changes the theme when the account cannot be reached',
      () async {
        await backend.signedInBefore();
        final preferences = emptyPreferences();
        final cubit = build(preferences);
        backend.offline = true;

        await cubit.select(AppThemeId.indigo);

        expect(cubit.state, AppThemeId.indigo);
        expect(preferences.themeName, 'indigo');
      },
    );

    test('does not call the API when signed out', () async {
      final cubit = build(emptyPreferences());

      await cubit.select(AppThemeId.indigo);
      await backend.auth.signOut();
      await pumpEventQueue();

      expect(backend.sent('PATCH /users/me'), isEmpty);
      expect(cubit.state, AppThemeId.indigo);
    });
  });
}
