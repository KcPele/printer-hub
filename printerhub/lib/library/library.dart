import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:documents_repository/documents_repository.dart';
import 'package:printerhub/library/library_item.dart';

/// Keeps a file the app made. The answer is what was kept, or null when
/// it could not be.
typedef KeepFile = Future<LibraryItem?> Function(
  File file, {
  required String mimeType,
  int? pageCount,
  String source,
  String? printerId,
  String? text,
});

/// Everything made on this phone, kept without being asked: scans, and
/// what the tools make.
///
/// A file is copied into the app's own folder the moment it is made, so
/// it is there with no network and after the app is closed. A copy then
/// goes to the person's account, at once when the API can be reached and
/// at the next [sync] when it cannot. In the account it is the person's
/// alone until they share it with the workspace.
class Library {
  new({
    required this._directory,
    required this._documents,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Directory _directory;
  final DocumentsRepository _documents;
  final DateTime Function() _now;

  final StreamController<void> _changes = StreamController.broadcast();
  final List<LibraryItem> _items = [];
  final Map<String, DateTime> _synced = {};
  bool _opened = false;
  Future<void>? _pass;

  /// Fires when something is added, changed, removed, or reaches the
  /// account.
  Stream<void> get changes => _changes.stream;

  File get _index => File('${_directory.path}/index.json');

  /// Reads what was kept before. Done once; asking again does nothing.
  ///
  /// The list is small, so it is read in one go: what was kept is known
  /// before anything asks for it.
  void open() {
    if (_opened) return;
    _opened = true;
    try {
      if (!_index.existsSync()) return;
      final kept =
          jsonDecode(_index.readAsStringSync()) as Map<String, dynamic>;
      for (final item in kept['items'] as List<dynamic>) {
        final written = item as Map<String, dynamic>;
        final read = LibraryItem.fromJson({
          ...written,
          // Where the app's folder is changes when the app is updated, so
          // a file is written down by its place inside the library.
          'path': '${_directory.path}/${written['path']}',
        });
        // A file the phone has cleared away is not offered.
        if (File(read.path).existsSync()) _items.add(read);
      }
      (kept['synced'] as Map<String, dynamic>).forEach(
        (organization, at) =>
            _synced[organization] = DateTime.parse(at as String),
      );
    } on Object {
      // A list that cannot be read is begun again: the account still has
      // what reached it.
      _items.clear();
      _synced.clear();
    }
  }

  void _save() {
    _directory.createSync(recursive: true);
    File('${_index.path}.new')
      ..writeAsStringSync(
        jsonEncode({
          'items': [
            for (final item in _items)
              {
                ...item.toJson(),
                'path': item.path.substring(_directory.path.length + 1),
              },
          ],
          'synced': {
            for (final MapEntry(:key, :value) in _synced.entries)
              key: value.toUtc().toIso8601String(),
          },
        }),
        flush: true,
      )
      // Swapped in whole, so a list half written is never read.
      ..renameSync(_index.path);
    if (!_changes.isClosed) _changes.add(null);
  }

  /// What was made in a workspace, newest first.
  List<LibraryItem> of(String organizationId) {
    return [
      for (final item in _items)
        if (item.organizationId == organizationId) item,
    ]..sort((a, b) => b.id.compareTo(a.id));
  }

  /// How many things made in a workspace the account does not have yet.
  int waiting(String organizationId) =>
      of(organizationId).where((item) => !item.synced).length;

  /// When everything made in a workspace last reached the account. Null
  /// when it never has.
  DateTime? lastSynced(String organizationId) => _synced[organizationId];

  /// The file of the document with this identifier, when this phone has
  /// it.
  File? fileOf(String id) {
    final item = _items.where((item) => item.id == id).firstOrNull;
    if (item == null) return null;
    final file = File(item.path);
    return file.existsSync() ? file : null;
  }

  /// A [KeepFile] for one workspace: keeps a file under its own name, and
  /// sends it to the account when it can.
  KeepFile keeper(String organizationId) {
    return (
      file, {
      required mimeType,
      pageCount,
      source = 'upload',
      printerId,
      text,
    }) async {
      try {
        final item = await add(
          organizationId: organizationId,
          file: file,
          mimeType: mimeType,
          pageCount: pageCount,
          source: source,
          printerId: printerId,
          text: text,
        );
        await sync(organizationId);
        return _items.where((kept) => kept.id == item.id).firstOrNull;
      } on FileSystemException {
        // No room on the phone: the file is still where it was made.
        return null;
      }
    };
  }

  /// Copies [file] into the library. It waits there for [sync].
  Future<LibraryItem> add({
    required String organizationId,
    required File file,
    required String mimeType,
    int? pageCount,
    String source = 'upload',
    String? printerId,
    String? text,
  }) async {
    open();
    final id = newRecordId(_now());
    final name = Uri.decodeComponent(file.uri.pathSegments.last);
    // A folder each, so two of a name do not meet.
    final folder = Directory('${_directory.path}/$id');
    await folder.create(recursive: true);
    final kept = await file.copy('${folder.path}/$name');
    final item = LibraryItem(
      id: id,
      organizationId: organizationId,
      name: name,
      path: kept.path,
      mimeType: mimeType,
      sizeBytes: await kept.length(),
      createdAt: _now(),
      pageCount: pageCount,
      source: source,
      printerId: printerId,
      text: text == null || text.trim().isEmpty ? null : text,
    );
    _items.add(item);
    _save();
    return item;
  }

  /// Sends what the account does not have yet, oldest first, and answers
  /// with how many are still waiting. Only one pass runs at a time: one
  /// asked for meanwhile runs after it.
  Future<int> sync(String organizationId) {
    final running = _pass;
    if (running != null) return running.then((_) => sync(organizationId));
    final pass = _sync(organizationId);
    // However it ends, the next one may begin.
    _pass = pass.then((_) {}, onError: (_) {});
    return pass.whenComplete(() => _pass = null);
  }

  Future<int> _sync(String organizationId) async {
    open();
    final pending = of(organizationId)
        .where((item) => !item.synced)
        .toList()
        .reversed;
    var reached = true;
    for (final item in pending) {
      final file = File(item.path);
      if (!file.existsSync()) {
        _items.remove(item);
        continue;
      }
      try {
        if (item.standing == LibraryStanding.recorded) {
          await _documents.finish(
            organizationId: organizationId,
            document: item.asDocument,
            file: file,
          );
        } else {
          await _documents.keep(
            organizationId: organizationId,
            id: item.id,
            file: file,
            name: item.name,
            mimeType: item.mimeType,
            pageCount: item.pageCount,
            source: item.source,
            printerId: item.printerId,
            text: item.text,
          );
        }
        _replace(item, item.copyWith(standing: LibraryStanding.synced));
      } on UploadInterrupted catch (interrupted) {
        final cause = interrupted.cause;
        if (cause is ApiProblem &&
            cause.code == 'document.upload_not_pending') {
          // It arrived on an earlier try that was never heard back from.
          _replace(item, item.copyWith(standing: LibraryStanding.synced));
        } else {
          _replace(item, item.copyWith(standing: LibraryStanding.recorded));
          if (cause is! ApiProblem) reached = false;
        }
      } on ApiProblem catch (problem) {
        _replace(
          item,
          problem.code == 'document.id_conflict'
              // The record was made on an earlier try: only the file is
              // owed.
              ? item.copyWith(standing: LibraryStanding.recorded)
              : item.copyWith(refused: true),
        );
      } on ApiException {
        // No network: the rest wait with this one.
        reached = false;
      }
      if (!reached) break;
    }
    final left = waiting(organizationId);
    if (reached && left == 0) _synced[organizationId] = _now();
    _save();
    return left;
  }

  void _replace(LibraryItem item, LibraryItem changed) {
    final at = _items.indexOf(item);
    if (at >= 0) _items[at] = changed;
  }

  /// Gives something a new name here. The account is told by whoever
  /// asked.
  Future<void> rename(String id, String name) async {
    final item = _items.where((item) => item.id == id).firstOrNull;
    if (item == null) return;
    _replace(item, item.copyWith(name: name));
    _save();
  }

  /// Takes something off this phone, with its file.
  Future<void> remove(String id) async {
    final item = _items.where((item) => item.id == id).firstOrNull;
    if (item == null) return;
    _items.remove(item);
    final folder = File(item.path).parent;
    if (folder.existsSync()) folder.deleteSync(recursive: true);
    _save();
  }

  Future<void> close() => _changes.close();
}
