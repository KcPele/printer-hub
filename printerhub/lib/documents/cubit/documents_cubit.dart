import 'dart:async';
import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:bloc/bloc.dart';
import 'package:documents_repository/documents_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:printerhub/app/remembered.dart';
import 'package:printerhub/documents/likeness.dart';
import 'package:printerhub/library/library.dart';
import 'package:printerhub/library/library_item.dart';
import 'package:printerhub/print/documents.dart';
import 'package:printerhub/scan/scan_output.dart';

enum DocumentsStatus { loading, ready, failed }

/// How far back a list of documents goes.
enum DocumentsAge {
  any,
  today,

  /// Today and the six days before it.
  week,

  /// Today and the twenty-nine days before it.
  month;

  /// The moment the list begins at, when it is [now]. Null for any time.
  DateTime? since(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      DocumentsAge.any => null,
      DocumentsAge.today => today,
      DocumentsAge.week => today.subtract(const Duration(days: 6)),
      DocumentsAge.month => today.subtract(const Duration(days: 29)),
    };
  }
}

/// What a list of documents is narrowed to: what made them, and when.
class DocumentsFilter extends Equatable {
  const new({this.sources = const {}, this.age = DocumentsAge.any});

  /// Where the documents came from, as `DocumentSources` names them.
  /// None is any.
  final Set<String> sources;
  final DocumentsAge age;

  /// True when it narrows nothing.
  bool get isEmpty => sources.isEmpty && age == DocumentsAge.any;

  @override
  List<Object?> get props => [sources, age];
}

class DocumentsState extends Equatable {
  const new({
    this.status = DocumentsStatus.loading,
    this.query = '',
    this.filter = const DocumentsFilter(),
    this.documents = const [],
    this.next,
    this.loadingMore = false,
    this.error,
    this.busyId,
    this.fetchFailed = false,
    this.onPhone = const {},
    this.waiting = const {},
    this.offline = false,
    this.thumbnails = const {},
  });

  final DocumentsStatus status;

  /// What the list is searched for.
  final String query;

  /// What the person narrowed the list to.
  final DocumentsFilter filter;

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

  /// What a document looks like, where this phone has its file and can
  /// draw it: the path of a small picture, by the document's identifier.
  /// A document that is not here is shown by a sign for its kind.
  final Map<String, String> thumbnails;

  /// True when [document] can be opened: this phone has its file, or the
  /// account does.
  bool canOpen(StoredDocument document) =>
      onPhone.contains(document.id) || document.canFetch;

  @override
  List<Object?> get props => [
    status,
    query,
    filter,
    documents,
    next,
    loadingMore,
    error,
    busyId,
    fetchFailed,
    onPhone,
    waiting,
    offline,
    thumbnails,
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
    required this._renderer,
    required this._sharer,
    required this._organizationId,
    this._sources = const {},
    this._bringsRecent = false,
    this._remembered,
    this._now = DateTime.now,
  }) : super(
         _remembered?.of<DocumentsState>(_place(_organizationId, _sources)) ??
             const DocumentsState(),
       ) {
    // Something was made, or reached the account: the list is read again
    // without being cleared first.
    _changes = _library.changes.listen((_) {
      if (state.status == DocumentsStatus.ready && state.busyId == null) {
        unawaited(_read(state.query, state.filter, quiet: true));
      }
    });
  }

  final DocumentsRepository _documentsRepository;
  final Library _library;
  final PageRenderer _renderer;
  final ScanSharer _sharer;
  final String _organizationId;

  /// What this list is only ever of: the documents one screen makes.
  /// None is every document. The person's own filter narrows it further.
  final Set<String> _sources;
  final DateTime Function() _now;

  /// Where a list of [sources] is kept between visits.
  static String _place(String organizationId, Set<String> sources) =>
      'documents.$organizationId.${(sources.toList()..sort()).join(',')}';

  /// The sources asked for: the person's choice, or what this list is of.
  Set<String> _wanted(DocumentsFilter filter) =>
      filter.sources.isEmpty ? _sources : filter.sources;

  /// True for a list on screen: the newest few documents that are only in
  /// the account are brought onto the phone as it is read.
  final bool _bringsRecent;
  bool _bringing = false;

  /// Where the list is kept between visits, so a screen opens on what it
  /// showed last and not on a wait.
  final Remembered? _remembered;

  @override
  void onChange(Change<DocumentsState> change) {
    super.onChange(change);
    final next = change.nextState;
    // The whole list as it stands at rest: not a search, not mid-change.
    if (next.status == DocumentsStatus.ready &&
        next.query.isEmpty &&
        next.filter.isEmpty &&
        next.busyId == null &&
        next.error == null &&
        !next.fetchFailed &&
        !next.loadingMore) {
      _remembered?.keep(_place(_organizationId, _sources), next);
    }
  }

  late final StreamSubscription<void> _changes;

  @override
  Future<void> close() async {
    await _changes.cancel();
    await super.close();
  }

  /// Counts the reads begun, so an answer that was overtaken is dropped.
  int _reads = 0;

  /// Reads the list from the start.
  Future<void> load() {
    // What is already shown stays until the news is in.
    return _read(
      state.query,
      state.filter,
      quiet: state.status == DocumentsStatus.ready,
    );
  }

  /// Reads the list again for the documents that match [query].
  Future<void> search(String query) => _read(query, state.filter);

  /// Reads the list again, narrowed to [filter].
  Future<void> filterBy(DocumentsFilter filter) {
    if (filter == state.filter) return Future.value();
    return _read(state.query, filter);
  }

  /// What this phone has that matches [query], newest first.
  List<LibraryItem> _local(String query, DocumentsFilter filter) {
    final wanted = query.trim().toLowerCase();
    final sources = _wanted(filter);
    final since = filter.age.since(_now());
    return [
      for (final item in _library.of(_organizationId))
        if ((wanted.isEmpty ||
                item.name.toLowerCase().contains(wanted) ||
                (item.text?.toLowerCase().contains(wanted) ?? false)) &&
            (sources.isEmpty || sources.contains(item.source)) &&
            (since == null || !item.createdAt.isBefore(since)))
          item,
    ];
  }

  Future<void> _read(
    String query,
    DocumentsFilter filter, {
    bool quiet = false,
  }) async {
    final read = ++_reads;
    if (!quiet) emit(DocumentsState(query: query, filter: filter));
    _library.open();
    try {
      final page = await _documentsRepository.list(
        organizationId: _organizationId,
        query: query,
        sources: _wanted(filter),
        since: filter.age.since(_now()),
      );
      if (read != _reads || isClosed) return;
      final local = _local(query, filter);
      final listed = {for (final document in page.documents) document.id};
      emit(
        DocumentsState(
          status: DocumentsStatus.ready,
          query: query,
          filter: filter,
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
          thumbnails: state.thumbnails,
        ),
      );
      await _draw(read);
      if (_bringsRecent && !quiet) unawaited(bringRecent());
    } on ApiProblem catch (error) {
      if (read != _reads || isClosed) return;
      emit(
        quiet
            // What was read before is still worth showing.
            ? _with(error: error)
            : DocumentsState(
                status: DocumentsStatus.failed,
                query: query,
                filter: filter,
                error: error,
              ),
      );
    } on ApiException {
      // No network: what this phone has is still there to open.
      if (read != _reads || isClosed) return;
      final local = _local(query, filter);
      emit(
        DocumentsState(
          status: DocumentsStatus.ready,
          query: query,
          filter: filter,
          documents: [for (final item in local) item.asDocument],
          onPhone: _onPhone,
          waiting: {
            for (final item in local)
              if (!item.synced) item.id,
          },
          offline: true,
          thumbnails: state.thumbnails,
        ),
      );
      await _draw(read);
    }
  }

  /// The most documents brought onto the phone at a time, and the largest
  /// that is brought without being asked for.
  static const int _mostBrought = 6;
  static const int _largestBrought = 8 * 1024 * 1024;

  /// Brings the newest few documents that are only in the account onto
  /// this phone, quietly: a scan made on another phone, or before the app
  /// was installed again, then shows what it looks like and opens with no
  /// network. Large ones wait to be opened. It stops at the first that
  /// cannot be fetched.
  Future<void> bringRecent() async {
    if (_bringing) return;
    _bringing = true;
    try {
      var brought = 0;
      for (final document in [...state.documents]) {
        if (isClosed || brought == _mostBrought) return;
        if (!document.canFetch ||
            document.sizeBytes > _largestBrought ||
            _library.fileOf(document.id) != null) {
          continue;
        }
        final fetched = await _documentsRepository.fetch(
          organizationId: _organizationId,
          document: document,
        );
        // The library says it has changed, and the list is read again
        // with the document's likeness in it.
        await _library.adopt(
          organizationId: _organizationId,
          document: document,
          file: fetched,
        );
        brought++;
      }
    } on Exception {
      // No network, or no file: they keep their signs until opened.
    } finally {
      _bringing = false;
    }
  }

  /// Finds what each document on this phone looks like, one at a time,
  /// and shows each as it is found. A picture is its own likeness; a PDF
  /// is drawn once and the drawing kept beside it.
  Future<void> _draw(int read) async {
    for (final document in state.documents) {
      if (state.thumbnails.containsKey(document.id)) continue;
      final file = _library.fileOf(document.id);
      if (file == null) continue;
      final picture = await _likeness(document, file);
      if (read != _reads || isClosed) return;
      if (picture == null) continue;
      emit(
        _with(
          busyId: state.busyId,
          thumbnails: {...state.thumbnails, document.id: picture.path},
        ),
      );
    }
  }

  Future<File?> _likeness(StoredDocument document, File file) {
    return likenessOf(
      _renderer,
      file,
      mimeType: document.mimeType,
      kept: File('${file.parent.path}/thumbnail.png'),
    );
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
        sources: _wanted(state.filter),
        since: state.filter.age.since(_now()),
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
  Future<void> send(StoredDocument document) async {
    final file = await fetch(document);
    if (file == null || isClosed) return;
    await _sharer.share([file], name: document.name);
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
      final fetched = await _documentsRepository.fetch(
        organizationId: _organizationId,
        document: document,
      );
      // Kept on this phone from now on: it opens with no network, and the
      // list can show what it looks like.
      final file = await _library.adopt(
        organizationId: _organizationId,
        document: document,
        file: fetched,
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
    Map<String, String>? thumbnails,
  }) {
    return DocumentsState(
      status: state.status,
      query: state.query,
      filter: state.filter,
      documents: documents ?? state.documents,
      next: next == null ? state.next : next(),
      loadingMore: loadingMore,
      error: error,
      busyId: busyId,
      fetchFailed: fetchFailed,
      onPhone: state.onPhone,
      waiting: state.waiting,
      offline: state.offline,
      thumbnails: thumbnails ?? state.thumbnails,
    );
  }
}
