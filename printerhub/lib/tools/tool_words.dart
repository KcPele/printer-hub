import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/tools/code.dart';
import 'package:printerhub/tools/made_pages.dart';
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

  /// What a code read by the camera holds.
  static String codeKind(AppLocalizations l10n, CodeKind kind) {
    return switch (kind) {
      CodeKind.link => l10n.toolsCodeLink,
      CodeKind.wifi => l10n.toolsCodeWifi,
      CodeKind.text => l10n.toolsCodeText,
    };
  }

  /// A page the app can print with no file.
  static String printable(AppLocalizations l10n, Printable kind) {
    return switch (kind) {
      Printable.lined => l10n.toolsPrintableLined,
      Printable.grid => l10n.toolsPrintableGrid,
      Printable.dots => l10n.toolsPrintableDots,
      Printable.checklist => l10n.toolsPrintableChecklist,
      Printable.calendar => l10n.toolsPrintableCalendar,
    };
  }

  /// The words a calendar of one month is made with: its name, and the
  /// days of the week from the day a week begins on here.
  static CalendarMonth calendar(
    AppLocalizations l10n,
    MaterialLocalizations material,
    int year,
    int month,
  ) {
    // Sunday is 0 to Material and 7 to a date.
    final first = material.firstDayOfWeekIndex == 0
        ? DateTime.sunday
        : material.firstDayOfWeekIndex;
    final day = DateFormat.E(l10n.localeName);
    return CalendarMonth(
      year: year,
      month: month,
      title: material.formatMonthYear(DateTime(year, month)),
      firstWeekday: first,
      weekdays: [
        // The fifth of January 2026 was a Monday.
        for (var i = 0; i < 7; i++)
          day.format(DateTime(2026, 1, 5 + (first - 1 + i) % 7)),
      ],
    );
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
