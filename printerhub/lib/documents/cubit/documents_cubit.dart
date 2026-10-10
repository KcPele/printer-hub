import 'dart:async';
import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:bloc/bloc.dart';
import 'package:documents_repository/documents_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:printerhub/library/library.dart';
import 'package:printerhub/library/library_item.dart';
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
    this.onPhone = const {},
    this.waiting = const {},
    this.offline = false,
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

  /// The documents whose file this phone has, by identifier. They open
  /// with no network.
  final Set<String> onPhone;

  /// Those the account does not have yet: made on this phone, and waiting
  /// to be sent.
  final Set<String> waiting;

  /// True when the account could not be reached, and the list is what
  /// this phone has.
  final bool offline;

  /// True when [document] can be opened: this phone has its file, or the
  /// account does.
  bool canOpen(StoredDocument document) =>
      onPhone.contains(document.id) || document.canFetch;

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
    onPhone,
    waiting,
    offline,
  ];
}

/// The person's documents: what they made on this phone, what their
/// account holds from their other devices, and what other members have
/// shared with the workspace. Listed, searched, opened, renamed, shared,
/// and deleted.
class DocumentsCubit extends Cubit<DocumentsState> {
  new({
    required this._documentsRepository,
    required this._library,
    required this._sharer,
    required this._organizationId,
  }) : super(const DocumentsState()) {
    // Something was made, or reached the account: the list is read again
    // without being cleared first.
    _changes = _library.changes.listen((_) {
      if (state.status == DocumentsStatus.ready && state.busyId == null) {
        unawaited(_read(state.query, quiet: true));
      }
    });
  }

  final DocumentsRepository _documentsRepository;
  final Library _library;
  final ScanSharer _sharer;
  final String _organizationId;
  late final StreamSubscription<void> _changes;

  @override
  Future<void> close() async {
    await _changes.cancel();
    await super.close();
  }

  /// Counts the reads begun, so an answer that was overtaken is dropped.
  int _reads = 0;

  /// Reads the list from the start.
  Future<void> load() => search(state.query);

  /// Reads the list again for the documents that match [query].
  Future<void> search(String query) => _read(query);

  /// What this phone has that matches [query], newest first.
  List<LibraryItem> _local(String query) {
    final wanted = query.trim().toLowerCase();
    return [
      for (final item in _library.of(_organizationId))
        if (wanted.isEmpty ||
            item.name.toLowerCase().contains(wanted) ||
            (item.text?.toLowerCase().contains(wanted) ?? false))
          item,
    ];
  }

  Future<void> _read(String query, {bool quiet = false}) async {
    final read = ++_reads;
    if (!quiet) emit(DocumentsState(query: query));
    _library.open();
    try {
      final page = await _documentsRepository.list(
        organizationId: _organizationId,
        query: query,
      );
      if (read != _reads || isClosed) return;
      final local = _local(query);
      final listed = {for (final document in page.documents) document.id};
      emit(
        DocumentsState(
          status: DocumentsStatus.ready,
          query: query,
          documents: [
            // What the account does not have yet comes first: it is the
            // newest.
            for (final item in local)
              if (!item.synced && !listed.contains(item.id)) item.asDocument,
            ...page.documents,
          ],
          next: page.next,
          onPhone: _onPhone,
          waiting: {
            for (final item in local)
              if (!item.synced && !listed.contains(item.id)) item.id,
          },
        ),
      );
    } on ApiProblem catch (error) {
      if (read != _reads || isClosed) return;
      emit(
        DocumentsState(
          status: DocumentsStatus.failed,
          query: query,
          error: error,
        ),
      );
    } on ApiException {
      // No network: what this phone has is still there to open.
      if (read != _reads || isClosed) return;
      final local = _local(query);
      emit(
        DocumentsState(
          status: DocumentsStatus.ready,
          query: query,
          documents: [for (final item in local) item.asDocument],
          onPhone: _onPhone,
          waiting: {
            for (final item in local)
              if (!item.synced) item.id,
          },
          offline: true,
        ),
      );
    }
  }

  Set<String> get _onPhone => {
    for (final item in _library.of(_organizationId)) item.id,
  };

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
    final file = await fetch(document);
    if (file != null) await _sharer.share([file], name: document.name);
  }

  /// Brings a document's file onto the phone, to print it. Null when it
  /// could not be fetched; the state then says why.
  Future<File?> fetch(StoredDocument document) async {
    if (state.busyId != null) return null;
    // Made on this phone, or fetched before: it is here already.
    final here = _library.fileOf(document.id);
    if (here != null) return here;
    if (!document.canFetch) return null;
    emit(_with(busyId: document.id));
    try {
      final file = await _documentsRepository.fetch(
        organizationId: _organizationId,
        document: document,
      );
      if (isClosed) return null;
      emit(_with());
      return file;
    } on ApiException catch (error) {
      if (!isClosed) emit(_with(error: error));
    } on TransferFailed {
      if (!isClosed) emit(_with(fetchFailed: true));
    }
    return null;
  }

  Future<void> rename(StoredDocument document, String name) {
    return _change(document, () async {
      // One the account does not have yet is renamed here, and sent under
      // its new name.
      final renamed = state.waiting.contains(document.id)
          ? StoredDocument(
              id: document.id,
              name: name,
              mimeType: document.mimeType,
              sizeBytes: document.sizeBytes,
              createdAt: document.createdAt,
              pageCount: document.pageCount,
              source: document.source,
              printerId: document.printerId,
            )
          : await _documentsRepository.rename(
              organizationId: _organizationId,
              documentId: document.id,
              name: name,
            );
      await _library.rename(document.id, name);
      return [
        for (final other in state.documents)
          if (other.id == document.id) renamed else other,
      ];
    });
  }

  Future<void> remove(StoredDocument document) {
    return _change(document, () async {
      if (!state.waiting.contains(document.id)) {
        await _documentsRepository.delete(
          organizationId: _organizationId,
          documentId: document.id,
        );
      }
      await _library.remove(document.id);
      return [
        for (final other in state.documents)
          if (other.id != document.id) other,
      ];
    });
  }

  /// Lets the other members of the workspace see a document, or, with
  /// [shared] false, keeps it to its owner again.
  Future<void> share(StoredDocument document, {required bool shared}) {
    return _change(document, () async {
      final changed = await _documentsRepository.share(
        organizationId: _organizationId,
        documentId: document.id,
        shared: shared,
      );
      return [
        for (final other in state.documents)
          if (other.id == document.id) changed else other,
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
      onPhone: state.onPhone,
      waiting: state.waiting,
      offline: state.offline,
    );
  }
}
