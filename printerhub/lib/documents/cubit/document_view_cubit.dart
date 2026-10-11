import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:printerhub/documents/open_document.dart';
import 'package:printerhub/print/documents.dart';
import 'package:printerhub/scan/scan_output.dart';

enum DocumentViewStatus { loading, ready, failed }

class DocumentViewState extends Equatable {
  const new({this.status = DocumentViewStatus.loading, this.pages = const []});

  final DocumentViewStatus status;

  /// The document's pages as pictures, as far as they have been drawn.
  final List<File> pages;

  @override
  List<Object?> get props => [
    status,
    [for (final page in pages) page.path],
  ];
}

/// Shows a document on the phone: a picture as it is, a PDF drawn a page
/// at a time. The pages appear as they are drawn, so a long document can
/// be read from its first page while the rest arrive.
///
/// A PDF is drawn once. Its pages are kept as pictures beside it, so the
/// next time it is opened they are there at once.
class DocumentViewCubit extends Cubit<DocumentViewState> {
  new({required this._renderer, required this._sharer, required this._document})
    : super(const DocumentViewState());

  final PageRenderer _renderer;
  final ScanSharer _sharer;
  final OpenDocument _document;

  /// Where a PDF's drawn pages are kept, and the mark that says every
  /// page is there.
  Directory get _drawn => Directory('${_document.file.path}.pages');
  File get _complete => File('${_drawn.path}/complete');

  /// Shows the document's pages: from where they are kept, or drawn now.
  Future<void> load() async {
    try {
      if (_document.isPicture) {
        emit(
          _document.file.existsSync()
              ? DocumentViewState(
                  status: DocumentViewStatus.ready,
                  pages: [_document.file],
                )
              : const DocumentViewState(status: DocumentViewStatus.failed),
        );
        return;
      }
      if (!_document.isPdf) {
        // A kind of file the phone cannot draw: it can still be shared to
        // an app that can.
        emit(const DocumentViewState(status: DocumentViewStatus.failed));
        return;
      }
      if (_complete.existsSync()) {
        final kept =
            _drawn
                .listSync()
                .whereType<File>()
                .where((file) => file.path.endsWith('.png'))
                .toList()
              ..sort((a, b) => a.path.compareTo(b.path));
        emit(DocumentViewState(status: DocumentViewStatus.ready, pages: kept));
        return;
      }

      // Begun afresh: a drawing that was cut short is not trusted.
      if (_drawn.existsSync()) _drawn.deleteSync(recursive: true);
      _drawn.createSync(recursive: true);
      final pages = <File>[];
      await for (final page in _renderer.pictures(_document.picked)) {
        if (isClosed) return;
        final number = '${pages.length + 1}'.padLeft(5, '0');
        pages.add(
          File('${_drawn.path}/page-$number.png')
            ..writeAsBytesSync(page, flush: true),
        );
        emit(DocumentViewState(pages: [...pages]));
      }
      if (isClosed) return;
      if (pages.isEmpty) {
        emit(const DocumentViewState(status: DocumentViewStatus.failed));
        return;
      }
      _complete.writeAsStringSync('');
      emit(DocumentViewState(status: DocumentViewStatus.ready, pages: pages));
    } on Object {
      if (!isClosed) {
        emit(const DocumentViewState(status: DocumentViewStatus.failed));
      }
    }
  }

  /// Hands the document to the phone's share sheet.
  Future<void> share() {
    return _sharer.share([_document.file], name: _document.name);
  }
}
