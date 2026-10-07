import 'package:app_ui/app_ui.dart';
import 'package:printerhub/l10n/l10n.dart';

extension AppThemeIdName on AppThemeId {
  /// The theme's name as shown to the user.
  String label(AppLocalizations l10n) => switch (this) {
    AppThemeId.volt => l10n.themeVolt,
    AppThemeId.indigo => l10n.themeIndigo,
    AppThemeId.mint => l10n.themeMint,
  };
}
