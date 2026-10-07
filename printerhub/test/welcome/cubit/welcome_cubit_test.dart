import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/welcome/welcome.dart';

import '../../helpers/helpers.dart';

void main() {
  group('WelcomeCubit', () {
    late MockPreferencesRepository preferences;

    setUp(() => preferences = emptyPreferences());

    test('starts on the first screen', () {
      final cubit = WelcomeCubit(preferencesRepository: preferences);

      expect(cubit.state, const WelcomeState());
      expect(cubit.state.page, 0);
      expect(cubit.state.isLastPage, isFalse);
      expect(cubit.state.finished, isFalse);
    });

    blocTest<WelcomeCubit, WelcomeState>(
      'follows the screen in view',
      build: () => WelcomeCubit(preferencesRepository: preferences),
      act: (cubit) => cubit
        ..pageChanged(1)
        ..pageChanged(WelcomeCubit.pageCount - 1),
      expect: () => const [
        WelcomeState(page: 1),
        WelcomeState(page: WelcomeCubit.pageCount - 1),
      ],
      verify: (cubit) => expect(cubit.state.isLastPage, isTrue),
    );

    blocTest<WelcomeCubit, WelcomeState>(
      'remembers that the welcome screens were seen, then finishes',
      build: () => WelcomeCubit(preferencesRepository: preferences),
      seed: () => const WelcomeState(page: 2),
      act: (cubit) => cubit.finish(),
      expect: () => const [WelcomeState(page: 2, finished: true)],
      verify: (_) {
        verify(preferences.completeOnboarding).called(1);
        expect(preferences.onboardingCompleted, isTrue);
      },
    );
  });
}
