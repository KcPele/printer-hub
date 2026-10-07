import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_repository/preferences_repository.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('PreferencesRepository', () {
    test('has no theme on a new install', () async {
      final repository = await PreferencesRepository.open();

      expect(repository.themeName, isNull);
    });

    test('remembers the chosen theme', () async {
      final repository = await PreferencesRepository.open();

      await repository.saveThemeName('mint');

      expect(repository.themeName, 'mint');
    });

    test('keeps the theme for the next launch', () async {
      final first = await PreferencesRepository.open();
      await first.saveThemeName('indigo');

      final second = await PreferencesRepository.open();

      expect(second.themeName, 'indigo');
    });

    test('shows the welcome screens on a new install', () async {
      final repository = await PreferencesRepository.open();

      expect(repository.onboardingCompleted, isFalse);
    });

    test('remembers that the welcome screens were seen', () async {
      final first = await PreferencesRepository.open();
      await first.completeOnboarding();

      final second = await PreferencesRepository.open();

      expect(first.onboardingCompleted, isTrue);
      expect(second.onboardingCompleted, isTrue);
    });

    test('remembers the workspace in use, and forgets it', () async {
      final repository = await PreferencesRepository.open();
      expect(repository.activeOrganizationId, isNull);

      await repository.saveActiveOrganizationId('org-1');
      expect(repository.activeOrganizationId, 'org-1');
      expect(
        (await PreferencesRepository.open()).activeOrganizationId,
        'org-1',
      );

      await repository.saveActiveOrganizationId(null);
      expect(repository.activeOrganizationId, isNull);
    });
  });
}
