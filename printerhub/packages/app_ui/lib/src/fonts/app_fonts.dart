import 'package:flutter/services.dart';

/// The font families the themes use.
abstract final class AppFonts {
  /// Volt's font. It is commercial, so its files are not in the repository:
  /// see `assets/fonts/lufga/README.md`. [loadLicensed] registers it when the
  /// files are present. Without them, text falls back to the system font.
  static const String lufga = 'Lufga';

  /// Indigo's font, bundled with this package.
  static const String plusJakartaSans = 'packages/app_ui/PlusJakartaSans';

  /// Mint's font, bundled with this package.
  static const String manrope = 'packages/app_ui/Manrope';

  static const String _lufgaFolder = 'assets/fonts/lufga/';

  /// Registers the licensed fonts found in the app's assets.
  ///
  /// Call once before the first frame. Returns how many font files were
  /// loaded, which is zero on a checkout without the licensed files.
  static Future<int> loadLicensed({AssetBundle? bundle}) async {
    final assets = bundle ?? rootBundle;
    final manifest = await AssetManifest.loadFromAssetBundle(assets);
    final files = manifest.listAssets().where(_isLufgaFont).toList();
    if (files.isEmpty) return 0;

    final loader = FontLoader(lufga);
    for (final file in files) {
      loader.addFont(assets.load(file));
    }
    await loader.load();
    return files.length;
  }

  static bool _isLufgaFont(String asset) {
    final name = asset.toLowerCase();
    return name.contains(_lufgaFolder) &&
        (name.endsWith('.ttf') || name.endsWith('.otf'));
  }
}
