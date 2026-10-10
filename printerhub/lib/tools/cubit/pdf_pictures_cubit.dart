import 'dart:io';
import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:printerhub/print/documents.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/tools/cubit/tool_state.dart';
import 'package:printerhub/tools/tools_output.dart';

/// Turns a PDF the person chooses into pictures: one a page, or with
/// [long] every page joined into one tall picture.
class PdfPicturesCubit extends Cubit<ToolState> {
  new({
    required this._picker,
    required this._renderer,
    required this._sharer,
    required this.long,
    Directory? directory,
  }) : _directory = directory ?? Directory.systemTemp,
       super(const ToolState());

  final DocumentPicker _picker;
  final PageRenderer _renderer;
  final ScanSharer _sharer;
  final Directory _directory;
  bool _busy = false;

  /// True makes one tall picture of all the pages.
  final bool long;

  /// Asks for a PDF and makes the pictures.
  Future<void> choose() async {
    if (_busy) return;
    _busy = true;
    try {
      await _work(await _picker.pickPdf());
    } finally {
      _busy = false;
    }
  }

  Future<void> _work(PickedDocument? document) async {
    if (document == null || isClosed) return;
    final name = nameWithoutEnding(document.name);
    emit(ToolState(status: ToolStatus.working, name: name));

    try {
      final pages = <Uint8List>[];
      await for (final page in _renderer.pictures(document)) {
        pages.add(page);
        if (long && pages.length > maxLongPicturePages) {
          if (!isClosed) emit(ToolState(name: name, failure: 'tools.too_long'));
          return;
        }
      }
      final files = long
          ? [
              await pagesAsLongPicture(
                pages: pages,
                name: name,
                directory: _directory,
              ),
            ]
          : await pagesAsPictures(
              pages: pages,
              name: name,
              directory: _directory,
            );
      if (!isClosed) {
        emit(ToolState(status: ToolStatus.done, name: name, files: files));
      }
    } on Object {
      if (!isClosed) emit(ToolState(name: name, failure: 'tools.unreadable'));
    }
  }

  /// Hands the pictures to the phone's share sheet.
  Future<void> share() async {
    if (state.status != ToolStatus.done) return;
    await _sharer.share(state.files, name: state.name);
  }
}
