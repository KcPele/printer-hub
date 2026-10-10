import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/tools/tools.dart';

void main() {
  test('every failure of a tool has its own words', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(ToolWords.failure(l10n, 'tools.no_text'), contains('No words'));
    expect(
      ToolWords.failure(l10n, 'tools.too_long'),
      contains('$maxLongPicturePages pages'),
    );
    expect(ToolWords.failure(l10n, 'tools.unreadable'), contains('could not'));
    expect(ToolWords.failure(l10n, null), contains('could not'));
  });
}
