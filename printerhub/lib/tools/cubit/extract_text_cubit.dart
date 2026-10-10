import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:printerhub/print/documents.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/tools/cubit/tool_state.dart';
import 'package:printerhub/tools/tools_output.dart';

/// Reads the words in a file the person chooses, a PDF or a picture, on
/// the phone, and hands them on to be copied or shared.
class ExtractTextCubit extends Cubit<ToolState> {
  new({
    required this._picker,
    required this._renderer,
    required this._reader,
    required this._sharer,
    Directory? directory,
  }) : _directory = directory ?? Directory.systemTemp,
       super(const ToolState());

  final DocumentPicker _picker;
  final PageRenderer _renderer;
  final ScanTextReader _reader;
  final ScanSharer _sharer;
  final Directory _directory;
  bool _busy = false;

  /// Asks for a file and reads it.
  Future<void> choose() async {
    if (_busy) return;
    _busy = true;
    try {
      await _work(await _picker.pick());
    } finally {
      _busy = false;
    }
  }

  Future<void> _work(PickedDocument? document) async {
    if (document == null || isClosed) return;
    final name = nameWithoutEnding(document.name);
    emit(ToolState(status: ToolStatus.working, name: name));

    // A PDF's pages are drawn to pictures first: the reader reads pictures.
    final drawn = <File>[];
    try {
      final List<File> pictures;
      if (document.mimeType == 'application/pdf') {
        var number = 0;
        await for (final page in _renderer.pictures(document)) {
          final file = File(
            '${_directory.path}/read-${identityHashCode(this)}-${++number}.png',
          );
          await file.writeAsBytes(page, flush: true);
          drawn.add(file);
        }
        pictures = drawn;
      } else {
        pictures = [File(document.path)];
      }
      final text = (await _reader.read(pictures)).trim();
      if (isClosed) return;
      emit(
        text.isEmpty
            ? ToolState(name: name, failure: 'tools.no_text')
            : ToolState(status: ToolStatus.done, name: name, text: text),
      );
    } on Object {
      if (!isClosed) emit(ToolState(name: name, failure: 'tools.unreadable'));
    } finally {
      for (final file in drawn) {
        if (file.existsSync()) file.deleteSync();
      }
    }
  }

  /// Hands the words to the phone's share sheet as a text file.
  Future<void> share() async {
    if (state.status != ToolStatus.done) return;
    final file = await textAsFile(
      text: state.text,
      name: state.name,
      directory: _directory,
    );
    await _sharer.share([file], name: state.name);
  }
}
