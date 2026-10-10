import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/tools/photo_sheet.dart';
import 'package:printerhub/tools/tools_output.dart';

/// The words the tools use for what went wrong.
abstract final class ToolWords {
  /// How photos are laid out on a sheet.
  static String layout(AppLocalizations l10n, PhotoLayout layout) {
    return switch (layout) {
      PhotoLayout.one => l10n.toolsPhotosOne,
      PhotoLayout.two => l10n.toolsPhotosTwo,
      PhotoLayout.four => l10n.toolsPhotosFour,
      PhotoLayout.passport => l10n.toolsPhotosPassport,
    };
  }

  /// Why a file came to nothing, from its code.
  static String failure(AppLocalizations l10n, String? code) {
    return switch (code) {
      'tools.no_text' => l10n.toolsNoText,
      'tools.too_long' => l10n.toolsTooLong(maxLongPicturePages),
      _ => l10n.toolsUnreadable,
    };
  }
}
