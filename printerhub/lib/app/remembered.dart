/// What screens showed last, kept while the app is open.
///
/// A screen that is opened again shows what it showed before at once, and
/// reads the news behind it, in place of starting from nothing each time.
/// Nothing here outlasts the app, and all of it goes when someone signs
/// out.
class Remembered {
  final Map<String, Object> _kept = {};

  /// What was kept under [key], when it is a [T].
  T? of<T extends Object>(String key) {
    final kept = _kept[key];
    return kept is T ? kept : null;
  }

  void keep(String key, Object value) => _kept[key] = value;

  /// Forgets everything: the next person to sign in starts clean.
  void clear() => _kept.clear();
}
