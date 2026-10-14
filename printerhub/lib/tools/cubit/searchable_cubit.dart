import 'dart:io';
import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:printerhub/documents/document_sources.dart';
import 'package:printerhub/library/library.dart';
import 'package:printerhub/print/documents.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/tools/cubit/tool_state.dart';
import 'package:printerhub/tools/pdf_font.dart';
import 'package:printerhub/tools/searchable_pdf.dart';

/// Makes a searchable PDF of a file the person chooses, a scan or a
/// picture: the words are read on the phone and laid, unseen, over each
/// page, so the PDF can be searched and its words copied.
class SearchableCubit extends Cubit<ToolState> {
  new({
    required this._picker,
    required this._renderer,
    required this._reader,
    required this._sharer,
    required this._keep,
    this._font = pdfFont,
    Directory? directory,
  }) : _directory = directory ?? Directory.systemTemp,
       super(const ToolState());

  final DocumentPicker _picker;
  final PageRenderer _renderer;
  final ScanTextReader _reader;
  final ScanSharer _sharer;
  final KeepFile _keep;
  final PdfFontLoader _font;
  final Directory _directory;
  bool _busy = false;

  /// Asks for a file and makes it searchable.
  Future<void> choose() async {
    if (_busy) return;
    _busy = true;
    try {
      await _work(await _picker.pick());
    } finally {
      _busy = false;
    }
  }

  /// Works on a document that is already open, with nothing to choose.
  Future<void> start(PickedDocument document) async {
    if (_busy) return;
    _busy = true;
    try {
      await _work(document);
    } finally {
      _busy = false;
    }
  }

  Future<void> _work(PickedDocument? document) async {
    if (document == null || isClosed) return;
    final name = '${nameWithoutEnding(document.name)} searchable';
    emit(ToolState(status: ToolStatus.working, name: name));

    // A PDF's pages are drawn to pictures first: the reader reads
    // pictures, and the new PDF is made of them.
    final drawn = <File>[];
    try {
      final pictures = <File>[];
      if (document.mimeType == 'application/pdf') {
        await for (final page in _renderer.pictures(document)) {
          final file = File(
            '${_directory.path}/searchable-${identityHashCode(this)}-'
            '${drawn.length + 1}.png',
          );
          await file.writeAsBytes(page, flush: true);
          drawn.add(file);
        }
        pictures.addAll(drawn);
      } else {
        pictures.add(File(document.path));
      }
      final pages = <ReadPage>[];
      for (final picture in pictures) {
        pages.add((
          picture: Uint8List.fromList(await picture.readAsBytes()),
          lines: await _reader.lines(picture),
        ));
      }
      if (isClosed) return;
      if (pages.every((page) => page.lines.isEmpty)) {
        emit(ToolState(name: name, failure: 'tools.no_text'));
        return;
      }
      final file = await searchablePdf(
        pages: pages,
        name: name,
        directory: _directory,
        font: await _font(),
      );
      if (!isClosed) {
        emit(ToolState(status: ToolStatus.done, name: name, files: [file]));
      }
      await _keep(
        file,
        mimeType: 'application/pdf',
        pageCount: pages.length,
        source: DocumentSources.searchablePdf,
      );
    } on Object {
      if (!isClosed) emit(ToolState(name: name, failure: 'tools.unreadable'));
    } finally {
      for (final file in drawn) {
        if (file.existsSync()) file.deleteSync();
      }
    }
  }

  /// Hands the PDF to the phone's share sheet.
  Future<void> share() async {
    if (state.status != ToolStatus.done) return;
    await _sharer.share(state.files, name: state.name);
  }
}
