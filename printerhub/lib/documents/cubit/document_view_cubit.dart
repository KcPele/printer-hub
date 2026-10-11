import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:printerhub/documents/open_document.dart';
import 'package:printerhub/library/library.dart';
import 'package:printerhub/print/documents.dart';
import 'package:printerhub/scan/scan_output.dart';

enum DocumentViewStatus { loading, ready, failed }

class DocumentViewState extends Equatable {
  const new({
    required this.document,
    this.status = DocumentViewStatus.loading,
    this.pages = const [],
    this.keeping = false,
  });

  /// The document that is open. It changes when a picture is changed and
  /// kept: the new document is then the one open.
  final OpenDocument document;
  final DocumentViewStatus status;

  /// The document's pages as pictures, as far as they have been drawn.
  final List<File> pages;

  /// True while a picture that was changed is being kept.
  final bool keeping;

  @override
  List<Object?> get props => [
    document,
    status,
    keeping,
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
  new({
    required this._renderer,
    required this._sharer,
    required OpenDocument document,
    this._keep,
  }) : super(DocumentViewState(document: document));

  final PageRenderer _renderer;
  final ScanSharer _sharer;

  /// Keeps a changed picture. Null where there is no workspace to keep it
  /// in.
  final KeepFile? _keep;

  OpenDocument get _document => state.document;

  /// True when the open document is a picture that can be changed and
  /// kept.
  bool get editable => _keep != null && _document.isPicture;

  DocumentViewState _now(
    DocumentViewStatus status, [
    List<File> pages = const [],
  ]) => DocumentViewState(document: _document, status: status, pages: pages);

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
              ? _now(DocumentViewStatus.ready, [_document.file])
              : _now(DocumentViewStatus.failed),
        );
        return;
      }
      if (!_document.isPdf) {
        // A kind of file the phone cannot draw: it can still be shared to
        // an app that can.
        emit(_now(DocumentViewStatus.failed));
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
        emit(_now(DocumentViewStatus.ready, kept));
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
        emit(_now(DocumentViewStatus.loading, [...pages]));
      }
      if (isClosed) return;
      if (pages.isEmpty) {
        emit(_now(DocumentViewStatus.failed));
        return;
      }
      _complete.writeAsStringSync('');
      emit(_now(DocumentViewStatus.ready, pages));
    } on Object {
      if (!isClosed) {
        emit(_now(DocumentViewStatus.failed));
      }
    }
  }

  /// Keeps [picture], the open picture as it was changed, as a new
  /// document called [name], and opens that one in its place. The
  /// document it was made from is left as it was. False when it could
  /// not be kept.
  Future<bool> keepChanged(File picture, {required String name}) async {
    final keep = _keep;
    if (keep == null || state.keeping) return false;
    final before = state;
    emit(
      DocumentViewState(
        document: before.document,
        status: before.status,
        pages: before.pages,
        keeping: true,
      ),
    );
    try {
      // Under its new name, so that is what it is kept as.
      final named = await picture.copy(
        '${picture.parent.path}/${scanFileName(name)}.jpg',
      );
      final kept = await keep(named, mimeType: 'image/jpeg', pageCount: 1);
      if (isClosed) return false;
      if (kept == null) {
        emit(before);
        return false;
      }
      final file = File(kept.path);
      emit(
        DocumentViewState(
          document: OpenDocument(
            file: file,
            name: kept.name,
            mimeType: 'image/jpeg',
          ),
          status: DocumentViewStatus.ready,
          pages: [file],
        ),
      );
      return true;
    } on FileSystemException {
      if (!isClosed) emit(before);
      return false;
    }
  }

  /// Hands the document to the phone's share sheet.
  Future<void> share() {
    return _sharer.share([_document.file], name: _document.name);
  }
}
