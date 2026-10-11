import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:printerhub/documents/likeness.dart';
import 'package:printerhub/documents/open_document.dart';
import 'package:printerhub/print/documents.dart';

/// Finds what files the app has just made look like, so each can be shown
/// by its picture: the path of a small picture, by the file's own path.
/// A file that cannot be drawn has none, and keeps the sign for its kind.
class MadeFilesCubit extends Cubit<Map<String, String>> {
  new({required this._renderer, required this._files}) : super(const {});

  final PageRenderer _renderer;
  final List<File> _files;

  /// Draws each file in turn, and shows each as it is drawn.
  Future<void> load() async {
    for (final file in _files) {
      final picture = await likenessOf(
        _renderer,
        file,
        mimeType: mimeTypeOfName(file.path),
        kept: File('${file.path}.thumbnail.png'),
      );
      if (isClosed) return;
      if (picture != null) emit({...state, file.path: picture.path});
    }
  }
}
