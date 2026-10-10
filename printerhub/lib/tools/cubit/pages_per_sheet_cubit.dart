import 'dart:io';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:printerhub/print/documents.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/tools/cubit/make_cubit.dart';
import 'package:printerhub/tools/made_pages.dart';

/// Which PDF, and how many of its pages go on a sheet.
class PagesPerSheetChoices extends Equatable {
  const new({this.document, this.perSheet = 2, this.paper = ScanPaper.a4});

  /// The PDF chosen, or null before one is.
  final PickedDocument? document;
  final int perSheet;
  final ScanPaper paper;

  PagesPerSheetChoices copyWith({
    PickedDocument? document,
    int? perSheet,
    ScanPaper? paper,
  }) {
    return PagesPerSheetChoices(
      document: document ?? this.document,
      perSheet: perSheet ?? this.perSheet,
      paper: paper ?? this.paper,
    );
  }

  @override
  List<Object?> get props => [document, perSheet, paper.name];
}

/// Sets the pages of a PDF two or four to a sheet, to save paper.
///
/// Each page is drawn as a picture first, so the words in the result can
/// no longer be picked out: it is for printing.
class PagesPerSheetCubit extends MakeCubit<PagesPerSheetChoices> {
  new({
    required super.sharer,
    required super.name,
    required this._picker,
    required this._renderer,
    super.directory,
  }) : super(choices: const PagesPerSheetChoices());

  final DocumentPicker _picker;
  final PageRenderer _renderer;
  bool _choosing = false;

  /// Asks for a PDF.
  Future<void> choose() async {
    if (_choosing || state.working) return;
    _choosing = true;
    try {
      final document = await _picker.pickPdf();
      if (document == null || isClosed) return;
      change(state.choices.copyWith(document: document));
    } finally {
      _choosing = false;
    }
  }

  @override
  bool ready(PagesPerSheetChoices choices) => choices.document != null;

  @override
  Future<File> build(PagesPerSheetChoices choices) async {
    final pages = <Uint8List>[];
    await _renderer.pictures(choices.document!).forEach(pages.add);
    return await pagesOnSheets(
      pages: pages,
      perSheet: choices.perSheet,
      paper: choices.paper,
      name: name,
      directory: directory,
    );
  }
}
