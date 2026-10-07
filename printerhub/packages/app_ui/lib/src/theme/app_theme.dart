import 'package:app_ui/src/theme/app_theme_id.dart';
import 'package:app_ui/src/theme/app_theme_tokens.dart';
import 'package:app_ui/src/theme/theme_data_builder.dart';
import 'package:app_ui/src/theme/themes/indigo.dart';
import 'package:app_ui/src/theme/themes/mint.dart';
import 'package:app_ui/src/theme/themes/volt.dart';
import 'package:material_ui/material_ui.dart';

/// One of the app's themes: a set of tokens per brightness.
///
/// Every theme ships [light]. A theme gains a dark variant by defining
/// [dark]; nothing that reads the theme has to change.
@immutable
class AppTheme {
  const new({required this.id, required this.light, this.dark});

  static const AppTheme volt = AppTheme(id: AppThemeId.volt, light: voltLight);

  static const AppTheme indigo = AppTheme(
    id: AppThemeId.indigo,
    light: indigoLight,
  );

  static const AppTheme mint = AppTheme(id: AppThemeId.mint, light: mintLight);

  /// Every theme, in the order Settings lists them.
  static const List<AppTheme> all = [volt, indigo, mint];

  static AppTheme of(AppThemeId id) => switch (id) {
    AppThemeId.volt => volt,
    AppThemeId.indigo => indigo,
    AppThemeId.mint => mint,
  };

  final AppThemeId id;
  final AppThemeTokens light;
  final AppThemeTokens? dark;

  /// Whether a dark variant exists yet.
  bool get hasDark => dark != null;

  /// The tokens for [brightness]. A theme without a dark variant answers
  /// with its light one.
  AppThemeTokens tokens(Brightness brightness) {
    return brightness == Brightness.dark ? dark ?? light : light;
  }

  /// The Material theme for [brightness].
  ThemeData data([Brightness brightness = Brightness.light]) {
    return buildThemeData(tokens(brightness));
  }
}
