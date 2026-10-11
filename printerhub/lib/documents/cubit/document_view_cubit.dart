import 'dart:io';
import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:printerhub/print/documents.dart';
import 'package:printerhub/scan/scan_output.dart';

enum DocumentViewStatus { loading, ready, failed }

class DocumentViewState extends Equatable {
  const new({this.status = DocumentViewStatus.loading, this.pages = const []});

  final DocumentViewStatus status;

  /// The document's pages as pictures, as far as they have been drawn.
  final List<Uint8List> pages;

  @override
  List<Object?> get props => [status, pages.length];
}

/// Shows a document on the phone: a picture as it is, a PDF drawn a page
/// at a time. The pages appear as they are drawn, so a long document can
/// be read from its first page while the rest arrive.
class DocumentViewCubit extends Cubit<DocumentViewState> {
  new({
    required this._renderer,
    required this._sharer,
    required this._file,
    required this._name,
    required this._mimeType,
  }) : super(const DocumentViewState());

  final PageRenderer _renderer;
  final ScanSharer _sharer;
  final File _file;
  final String _name;
  final String _mimeType;

  /// Draws the document's pages.
  Future<void> load() async {
    try {
      if (_mimeType.startsWith('image/')) {
        final picture = await _file.readAsBytes();
        if (!isClosed) {
          emit(
            DocumentViewState(
              status: DocumentViewStatus.ready,
              pages: [picture],
            ),
          );
        }
        return;
      }
      if (_mimeType != 'application/pdf') {
        // A kind of file the phone cannot draw: it can still be shared to
        // an app that can.
        emit(const DocumentViewState(status: DocumentViewStatus.failed));
        return;
      }
      final pages = <Uint8List>[];
      await for (final page in _renderer.pictures(
        PickedDocument.fromFile(_file),
      )) {
        if (isClosed) return;
        pages.add(page);
        emit(DocumentViewState(pages: [...pages]));
      }
      if (!isClosed) {
        emit(
          DocumentViewState(
            status: pages.isEmpty
                ? DocumentViewStatus.failed
                : DocumentViewStatus.ready,
            pages: pages,
          ),
        );
      }
    } on Object {
      if (!isClosed) {
        emit(const DocumentViewState(status: DocumentViewStatus.failed));
      }
    }
  }

  /// Hands the document to the phone's share sheet.
  Future<void> share() => _sharer.share([_file], name: _name);
}
