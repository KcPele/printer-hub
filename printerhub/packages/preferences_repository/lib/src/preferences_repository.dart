import 'package:shared_preferences/shared_preferences.dart';

/// Reads and writes the preferences that belong to this device.
///
/// Values are read from memory, so a caller can use them while building the
/// first frame.
class PreferencesRepository {
  new({required this._store});

  static const String _themeKey = 'app_theme';

  /// Opens the device's preferences and loads them into memory.
  static Future<PreferencesRepository> open() async {
    final store = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: {_themeKey},
      ),
    );
    return PreferencesRepository(store: store);
  }

  final SharedPreferencesWithCache _store;

  /// The name of the chosen theme, or null when none has been chosen.
  String? get themeName => _store.getString(_themeKey);

  /// Remembers the chosen theme.
  Future<void> saveThemeName(String name) => _store.setString(_themeKey, name);
}
