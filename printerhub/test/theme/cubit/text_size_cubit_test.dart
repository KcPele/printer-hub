import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/theme/theme.dart';

import '../../helpers/helpers.dart';

void main() {
  group('TextSizeCubit', () {
    test('is at the standard size until someone chooses', () {
      final cubit = TextSizeCubit(
        preferencesRepository: emptyPreferences(textSizePercent: null),
      );
      addTearDown(cubit.close);

      expect(cubit.state, 85);
      expect(cubit.factor, 0.85);
      // Full size is the largest on offer, and the smallest is 70%.
      expect(TextSizeCubit.sizes, [100, 95, 90, 85, 80, 75, 70]);
      expect(TextSizeCubit.sizes, contains(TextSizeCubit.standard));
    });

    test('starts with what was chosen on this phone', () {
      final cubit = TextSizeCubit(
        preferencesRepository: emptyPreferences(textSizePercent: 90),
      );
      addTearDown(cubit.close);

      expect(cubit.state, 90);
      expect(cubit.factor, 0.9);
    });

    test('takes a size that is not offered as the standard size', () {
      final cubit = TextSizeCubit(
        preferencesRepository: emptyPreferences(textSizePercent: 140),
      );
      addTearDown(cubit.close);

      expect(cubit.state, 85);
    });

    test('applies a choice at once and keeps it', () async {
      final preferences = emptyPreferences();
      final cubit = TextSizeCubit(preferencesRepository: preferences);
      addTearDown(cubit.close);

      await cubit.select(70);

      expect(cubit.state, 70);
      expect(preferences.textSizePercent, 70);

      // Chosen again, or a size that is not offered, changes nothing.
      await cubit.select(70);
      await cubit.select(120);
      expect(cubit.state, 70);
      verify(() => preferences.saveTextSizePercent(70)).called(1);
      verifyNever(() => preferences.saveTextSizePercent(120));
    });
  });
}
