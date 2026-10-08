import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:bloc/bloc.dart';
import 'package:documents_repository/documents_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:printerhub/scan/scan_output.dart';

enum DocumentsStatus { loading, ready, failed }

class DocumentsState extends Equatable {
  const new({
    this.status = DocumentsStatus.loading,
    this.query = '',
    this.documents = const [],
    this.next,
    this.loadingMore = false,
    this.error,
    this.busyId,
    this.fetchFailed = false,
  });

  final DocumentsStatus status;

  /// What the list is searched for.
  final String query;

  /// The documents the workspace keeps, newest first, as far as read.
  final List<StoredDocument> documents;

  /// Where the next page starts. Null when there is no more.
  final String? next;
  final bool loadingMore;

  /// Why the list could not be read, or a change could not be made. Pass
  /// it to `errorMessage`.
  final ApiException? error;

  /// The document being fetched, renamed, or deleted.
  final String? busyId;

  /// True when a document's file could not be brought onto the phone.
  final bool fetchFailed;

  @override
  List<Object?> get props => [
    status,
    query,
    documents,
    next,
    loadingMore,
    error,
    busyId,
    fetchFailed,
  ];
}

/// The documents a workspace keeps: listed, searched, opened, renamed, and
/// deleted.
class DocumentsCubit extends Cubit<DocumentsState> {
  new({
    required this._documentsRepository,
    required this._sharer,
    required this._organizationId,
  }) : super(const DocumentsState());

  final DocumentsRepository _documentsRepository;
  final ScanSharer _sharer;
  final String _organizationId;

  /// Counts the reads begun, so an answer that was overtaken is dropped.
  int _reads = 0;

  /// Reads the list from the start.
  Future<void> load() => search(state.query);

  /// Reads the list again for the documents that match [query].
  Future<void> search(String query) async {
    final read = ++_reads;
    emit(DocumentsState(query: query));
    try {
      final page = await _documentsRepository.list(
        organizationId: _organizationId,
        query: query,
      );
      if (read != _reads || isClosed) return;
      emit(
        DocumentsState(
          status: DocumentsStatus.ready,
          query: query,
          documents: page.documents,
          next: page.next,
        ),
      );
    } on ApiException catch (error) {
      if (read != _reads || isClosed) return;
      emit(
        DocumentsState(
          status: DocumentsStatus.failed,
          query: query,
          error: error,
        ),
      );
    }
  }

  /// Reads the next page.
  Future<void> more() async {
    final cursor = state.next;
    if (cursor == null || state.loadingMore) return;
    final read = _reads;
    emit(_with(loadingMore: true));
    try {
      final page = await _documentsRepository.list(
        organizationId: _organizationId,
        query: state.query,
        cursor: cursor,
      );
      if (read != _reads || isClosed) return;
      emit(
        _with(
          documents: [...state.documents, ...page.documents],
          next: () => page.next,
        ),
      );
    } on ApiException catch (error) {
      if (read != _reads || isClosed) return;
      emit(_with(error: error));
    }
  }

  /// Brings a document's file onto the phone and hands it to the share
  /// sheet, where it can be opened, saved, or sent.
  Future<void> open(StoredDocument document) async {
    if (state.busyId != null || !document.canFetch) return;
    emit(_with(busyId: document.id));
    try {
      final file = await _documentsRepository.fetch(
        organizationId: _organizationId,
        document: document,
      );
      if (isClosed) return;
      emit(_with());
      await _sharer.share([file], name: document.name);
    } on ApiException catch (error) {
      if (!isClosed) emit(_with(error: error));
    } on TransferFailed {
      if (!isClosed) emit(_with(fetchFailed: true));
    }
  }

  Future<void> rename(StoredDocument document, String name) {
    return _change(document, () async {
      final renamed = await _documentsRepository.rename(
        organizationId: _organizationId,
        documentId: document.id,
        name: name,
      );
      return [
        for (final other in state.documents)
          if (other.id == document.id) renamed else other,
      ];
    });
  }

  Future<void> remove(StoredDocument document) {
    return _change(document, () async {
      await _documentsRepository.delete(
        organizationId: _organizationId,
        documentId: document.id,
      );
      return [
        for (final other in state.documents)
          if (other.id != document.id) other,
      ];
    });
  }

  Future<void> _change(
    StoredDocument document,
    Future<List<StoredDocument>> Function() change,
  ) async {
    if (state.busyId != null) return;
    emit(_with(busyId: document.id));
    try {
      final documents = await change();
      if (!isClosed) emit(_with(documents: documents));
    } on ApiException catch (error) {
      if (!isClosed) emit(_with(error: error));
    }
  }

  DocumentsState _with({
    List<StoredDocument>? documents,
    String? Function()? next,
    bool loadingMore = false,
    ApiException? error,
    String? busyId,
    bool fetchFailed = false,
  }) {
    return DocumentsState(
      status: state.status,
      query: state.query,
      documents: documents ?? state.documents,
      next: next == null ? state.next : next(),
      loadingMore: loadingMore,
      error: error,
      busyId: busyId,
      fetchFailed: fetchFailed,
    );
  }
}
