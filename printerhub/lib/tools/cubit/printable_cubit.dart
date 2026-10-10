import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/tools/cubit/make_cubit.dart';
import 'package:printerhub/tools/made_pages.dart';
import 'package:printerhub/tools/pdf_font.dart';

/// Which ruled page is wanted, and for a calendar, which month.
class PrintableChoices extends Equatable {
  const new({
    required this.year,
    required this.month,
    this.kind = Printable.lined,
    this.paper = ScanPaper.a4,
  });

  final Printable kind;
  final ScanPaper paper;

  /// The calendar's month.
  final int year;
  final int month;

  PrintableChoices copyWith({Printable? kind, ScanPaper? paper}) {
    return PrintableChoices(
      kind: kind ?? this.kind,
      paper: paper ?? this.paper,
      year: year,
      month: month,
    );
  }

  /// The same choices, [months] later, or earlier when it is negative.
  PrintableChoices later(int months) {
    final moved = DateTime(year, month + months);
    return PrintableChoices(
      kind: kind,
      paper: paper,
      year: moved.year,
      month: moved.month,
    );
  }

  @override
  List<Object?> get props => [kind, paper.name, year, month];
}

/// Makes a page to print that needs no file: lined, squared, or dotted
/// paper, a checklist, or a month's calendar.
class PrintableCubit extends MakeCubit<PrintableChoices> {
  new({
    required super.sharer,
    required super.name,
    required DateTime today,
    required this._calendar,
    this._font = pdfFont,
    super.directory,
  }) : super(
         choices: PrintableChoices(year: today.year, month: today.month),
       );

  /// Words a calendar for a month, in the app's language.
  final CalendarMonth Function(int year, int month) _calendar;
  final PdfFontLoader _font;

  @override
  Future<File> build(PrintableChoices choices) async {
    final calendar = choices.kind == Printable.calendar;
    return await printableSheet(
      kind: choices.kind,
      paper: choices.paper,
      month: calendar ? _calendar(choices.year, choices.month) : null,
      name: name,
      directory: directory,
      // Only a calendar has words on it.
      font: calendar ? await _font() : null,
    );
  }
}
