import 'package:shared_preferences/shared_preferences.dart';

/// Reads and writes the preferences that belong to this device.
///
/// Values are read from memory, so a caller can use them while building the
/// first frame.
class PreferencesRepository {
  new({required this._store});

  static const String _themeKey = 'app_theme';
  static const String _brightnessKey = 'app_brightness';
  static const String _onboardingKey = 'onboarding_completed';
  static const String _organizationKey = 'active_organization_id';

  /// Opens the device's preferences and loads them into memory.
  static Future<PreferencesRepository> open() async {
    final store = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: {
          _themeKey,
          _brightnessKey,
          _onboardingKey,
          _organizationKey,
        },
      ),
    );
    return PreferencesRepository(store: store);
  }

  final SharedPreferencesWithCache _store;

  /// The name of the chosen theme, or null when none has been chosen.
  String? get themeName => _store.getString(_themeKey);

  /// Remembers the chosen theme.
  Future<void> saveThemeName(String name) => _store.setString(_themeKey, name);

  /// Whether the app is shown light, dark, or as the phone is: `light`,
  /// `dark`, or `system`. Null when nothing has been chosen.
  String? get brightnessName => _store.getString(_brightnessKey);

  /// Remembers whether the app is shown light, dark, or as the phone is.
  Future<void> saveBrightnessName(String name) {
    return _store.setString(_brightnessKey, name);
  }

  /// Whether the welcome screens have been seen on this device.
  bool get onboardingCompleted => _store.getBool(_onboardingKey) ?? false;

  /// Remembers that the welcome screens have been seen.
  Future<void> completeOnboarding() => _store.setBool(_onboardingKey, true);

  /// The workspace last used on this device, or null.
  String? get activeOrganizationId => _store.getString(_organizationKey);

  /// Remembers the workspace in use. Null forgets it.
  Future<void> saveActiveOrganizationId(String? id) {
    return id == null
        ? _store.remove(_organizationKey)
        : _store.setString(_organizationKey, id);
  }
}
