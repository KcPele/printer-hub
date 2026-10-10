import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/tools/cubit/make_cubit.dart';
import 'package:printerhub/tools/made_pages.dart';
import 'package:printerhub/tools/pdf_font.dart';

/// A note to print: what it is headed, and what it says.
class NoteChoices extends Equatable {
  const new({this.title = '', this.text = '', this.paper = ScanPaper.a4});

  final String title;
  final String text;
  final ScanPaper paper;

  NoteChoices copyWith({String? title, String? text, ScanPaper? paper}) {
    return NoteChoices(
      title: title ?? this.title,
      text: text ?? this.text,
      paper: paper ?? this.paper,
    );
  }

  @override
  List<Object?> get props => [title, text, paper.name];
}

/// Makes a document to print out of words typed or pasted in, with no
/// file needed.
class NoteCubit extends MakeCubit<NoteChoices> {
  new({
    required super.sharer,
    required super.keep,
    required super.name,
    this._font = pdfFont,
    super.directory,
  }) : super(choices: const NoteChoices());

  final PdfFontLoader _font;

  @override
  bool ready(NoteChoices choices) => choices.text.trim().isNotEmpty;

  @override
  Future<File> build(NoteChoices choices) async {
    return await noteSheet(
      title: choices.title,
      text: choices.text,
      paper: choices.paper,
      name: name,
      directory: directory,
      font: await _font(),
    );
  }
}
