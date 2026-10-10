import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/tools/tools_output.dart';

/// The words the tools use for what went wrong.
abstract final class ToolWords {
  /// Why a file came to nothing, from its code.
  static String failure(AppLocalizations l10n, String? code) {
    return switch (code) {
      'tools.no_text' => l10n.toolsNoText,
      'tools.too_long' => l10n.toolsTooLong(maxLongPicturePages),
      _ => l10n.toolsUnreadable,
    };
  }
}
