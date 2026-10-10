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

  test('every photo layout has its own words', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect({
      for (final layout in PhotoLayout.values) ToolWords.layout(l10n, layout),
    }, hasLength(PhotoLayout.values.length));
  });

  test('every kind of code and printable page has its own words', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect({
      for (final kind in CodeKind.values) ToolWords.codeKind(l10n, kind),
    }, hasLength(CodeKind.values.length));
    expect({
      for (final kind in Printable.values) ToolWords.printable(l10n, kind),
    }, hasLength(Printable.values.length));
  });

  test('a calendar is worded from the day a week begins on', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // In the United States a week begins on Sunday.
    final sunday = ToolWords.calendar(
      l10n,
      await GlobalMaterialLocalizations.delegate.load(const Locale('en', 'US')),
      2026,
      10,
    );
    expect(sunday.title, 'October 2026');
    expect(sunday.firstWeekday, DateTime.sunday);
    expect(sunday.weekdays, ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']);

    // In Britain, on Monday.
    final monday = ToolWords.calendar(
      l10n,
      await GlobalMaterialLocalizations.delegate.load(const Locale('en', 'GB')),
      2026,
      10,
    );
    expect(monday.firstWeekday, DateTime.monday);
    expect(monday.weekdays.first, 'Mon');
    expect(monday.weekdays.last, 'Sun');
  });
}
