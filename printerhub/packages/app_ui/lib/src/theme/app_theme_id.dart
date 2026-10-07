/// The themes a user can choose between in Settings.
enum AppThemeId {
  /// Mint on white, medium corners, hairline borders. The default.
  mint,

  /// Indigo on a cool grey, large corners, soft shadows.
  indigo,

  /// Charcoal and yellow, pill shapes, flat.
  volt;

  /// The theme a new install starts with.
  static const AppThemeId fallback = AppThemeId.mint;

  /// Reads a stored [name], falling back when it is missing or unknown.
  static AppThemeId fromName(String? name) {
    for (final id in values) {
      if (id.name == name) return id;
    }
    return fallback;
  }
}
