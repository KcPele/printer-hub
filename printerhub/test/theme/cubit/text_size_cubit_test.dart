import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/theme/theme.dart';

import '../../helpers/helpers.dart';

void main() {
  group('TextSizeCubit', () {
    test('is full size until someone chooses', () {
      final cubit = TextSizeCubit(preferencesRepository: emptyPreferences());
      addTearDown(cubit.close);

      expect(cubit.state, 100);
      expect(cubit.factor, 1);
      // Full size is the largest on offer.
      expect(TextSizeCubit.sizes.first, 100);
      expect(TextSizeCubit.sizes.every((size) => size <= 100), isTrue);
    });

    test('starts with what was chosen on this phone', () {
      final cubit = TextSizeCubit(
        preferencesRepository: emptyPreferences(textSizePercent: 90),
      );
      addTearDown(cubit.close);

      expect(cubit.state, 90);
      expect(cubit.factor, 0.9);
    });

    test('takes a size that is not offered as full size', () {
      final cubit = TextSizeCubit(
        preferencesRepository: emptyPreferences(textSizePercent: 140),
      );
      addTearDown(cubit.close);

      expect(cubit.state, 100);
    });

    test('applies a choice at once and keeps it', () async {
      final preferences = emptyPreferences();
      final cubit = TextSizeCubit(preferencesRepository: preferences);
      addTearDown(cubit.close);

      await cubit.select(85);

      expect(cubit.state, 85);
      expect(preferences.textSizePercent, 85);

      // Chosen again, or a size that is not offered, changes nothing.
      await cubit.select(85);
      await cubit.select(120);
      expect(cubit.state, 85);
      verify(() => preferences.saveTextSizePercent(85)).called(1);
      verifyNever(() => preferences.saveTextSizePercent(120));
    });
  });
}
