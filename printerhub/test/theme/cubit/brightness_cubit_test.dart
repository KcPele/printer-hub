import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/theme/theme.dart';

import '../../helpers/helpers.dart';

void main() {
  group('BrightnessCubit', () {
    test('looks as the phone does until someone chooses', () {
      final cubit = BrightnessCubit(preferencesRepository: emptyPreferences());
      addTearDown(cubit.close);

      expect(cubit.state, ThemeMode.system);
    });

    test('starts with what was chosen on this phone', () {
      for (final mode in ThemeMode.values) {
        final cubit = BrightnessCubit(
          preferencesRepository: emptyPreferences(brightnessName: mode.name),
        );
        addTearDown(cubit.close);

        expect(cubit.state, mode);
      }
    });

    test('takes a name it does not know as the phone’s own', () {
      final cubit = BrightnessCubit(
        preferencesRepository: emptyPreferences(brightnessName: 'sepia'),
      );
      addTearDown(cubit.close);

      expect(cubit.state, ThemeMode.system);
    });

    test('applies a choice at once and keeps it', () async {
      final preferences = emptyPreferences();
      final cubit = BrightnessCubit(preferencesRepository: preferences);
      addTearDown(cubit.close);

      await cubit.select(ThemeMode.dark);

      expect(cubit.state, ThemeMode.dark);
      expect(preferences.brightnessName, 'dark');

      // Choosing it again saves nothing.
      await cubit.select(ThemeMode.dark);
      verify(() => preferences.saveBrightnessName('dark')).called(1);
    });
  });
}
