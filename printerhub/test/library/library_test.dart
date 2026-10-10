import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/library/library.dart';
import 'package:printerhub/library/library_item.dart';

import '../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';
const _documents = 'POST /organizations/$_org/documents';

void main() {
  late TestBackend backend;
  late Library library;
  late Directory folder;
  late DateTime now;

  setUp(() async {
    backend = TestBackend();
    await backend.signedInBefore();
    folder = Directory('${backend.scans.path}/kept');
    now = DateTime.utc(2026, 10, 10, 9);
    library = Library(
      directory: folder,
      documents: backend.documentsKept,
      now: () => now,
    );
  });
  tearDown(() async {
    await library.close();
    await backend.close();
  });

  File made(String name, {String says = '%PDF made here'}) =>
      File('${backend.scans.path}/$name')..writeAsStringSync(says);

  Future<LibraryItem> add(
    String name, {
    String organizationId = _org,
    String? text,
  }) {
    // A moment later each time, as things are made.
    now = now.add(const Duration(seconds: 1));
    return library.add(
      organizationId: organizationId,
      file: made(name),
      mimeType: 'application/pdf',
      pageCount: 2,
      source: 'camera_scan',
      text: text,
    );
  }

  /// Another library over the same folder, as the app opened again.
  Library reopened() {
    final other = Library(directory: folder, documents: backend.documentsKept);
    addTearDown(other.close);
    return other;
  }

  group('add', () {
    test('copies the file into its own folder, where it outlasts the '
        'original', () async {
      final original = made('Note.pdf');
      final item = await library.add(
        organizationId: _org,
        file: original,
        mimeType: 'application/pdf',
      );
      original.deleteSync();

      expect(item.name, 'Note.pdf');
      expect(item.path, startsWith(folder.path));
      expect(item.path, isNot(original.path));
      expect(File(item.path).readAsStringSync(), '%PDF made here');
      expect(item.sizeBytes, 14);
      expect(item.standing, LibraryStanding.waiting);
      expect(item.synced, isFalse);
      expect(item.source, 'upload');
      expect(library.fileOf(item.id)!.path, item.path);
      expect(library.waiting(_org), 1);
    });

    test('keeps two of a name apart, newest first, a workspace at a '
        'time', () async {
      final first = await add('Note.pdf');
      final second = await add('Note.pdf');
      await add('Other.pdf', organizationId: 'another-workspace');

      expect(library.of(_org), [second, first]);
      expect(first.path, isNot(second.path));
      expect(library.of('another-workspace').single.name, 'Other.pdf');
      expect(library.waiting('nobody'), 0);
    });

    test('keeps the words read from it, when there are any', () async {
      expect((await add('A.pdf', text: 'Invoice 42')).text, 'Invoice 42');
      expect((await add('B.pdf', text: '  \n')).text, isNull);
    });

    test('says when something changes', () async {
      var changes = 0;
      final watching = library.changes.listen((_) => changes++);

      await add('Note.pdf');
      await pumpEventQueue();
      await watching.cancel();

      expect(changes, 1);
    });
  });

  group('what was kept', () {
    test('is there when the app is opened again', () async {
      final item = await add('Note.pdf', text: 'Buy toner');
      await library.sync(_org);

      // Reading it twice reads it once.
      final other = reopened()
        ..open()
        ..open();

      final read = other.of(_org).single;
      expect(read, library.of(_org).single);
      expect(read.id, item.id);
      expect(read.synced, isTrue);
      expect(read.text, 'Buy toner');
      expect(read.pageCount, 2);
      expect(other.lastSynced(_org), library.lastSynced(_org));
    });

    test('leaves out a file the phone has cleared away', () async {
      final item = await add('Note.pdf');
      File(item.path).deleteSync();

      final other = reopened()..open();

      expect(other.of(_org), isEmpty);
      expect(library.fileOf(item.id), isNull);
      expect(library.fileOf('unknown'), isNull);
    });

    test('is begun again when the list cannot be read', () async {
      await add('Note.pdf');
      File('${folder.path}/index.json').writeAsStringSync('{"items": [{}]}');

      final other = reopened()..open();

      expect(other.of(_org), isEmpty);
      // And it works from there.
      await other.add(
        organizationId: _org,
        file: made('New.pdf'),
        mimeType: 'application/pdf',
      );
      expect(other.of(_org).single.name, 'New.pdf');
    });

    test('is nothing before anything is kept', () async {
      library.open();

      expect(library.of(_org), isEmpty);
      expect(library.lastSynced(_org), isNull);
    });
  });

  group('sync', () {
    test('sends what is waiting to the account, oldest first, under the '
        'identifier the phone knows it by', () async {
      final first = await add('First.pdf', text: 'Invoice 42');
      final second = await add('Second.pdf');

      expect(await library.sync(_org), 0);

      expect(library.of(_org).every((item) => item.synced), isTrue);
      final sent = backend.sent(_documents);
      expect(sent, hasLength(2));
      // Listed newest first.
      expect(backend.documentList.map((d) => d['id']), [second.id, first.id]);
      expect(backend.documentList.last['file_name'], 'First.pdf');
      expect(backend.documentList.last['source'], 'camera_scan');
      expect(backend.documentList.last['page_count'], 2);
      expect(backend.documentList.last['shared'], isFalse);
      expect(backend.documentList.last['upload_status'], 'uploaded');
      expect(library.lastSynced(_org), now);
    });

    test('sends nothing twice', () async {
      await add('Note.pdf');
      await library.sync(_org);

      expect(await library.sync(_org), 0);

      expect(backend.sent(_documents), hasLength(1));
    });

    test('leaves everything waiting when the account cannot be reached, '
        'and sends it when it can', () async {
      await add('First.pdf');
      await add('Second.pdf');
      backend.offline = true;

      expect(await library.sync(_org), 2);
      expect(library.lastSynced(_org), isNull);
      expect(library.of(_org).map((item) => item.standing).toSet(), {
        LibraryStanding.waiting,
      });

      backend.offline = false;
      expect(await library.sync(_org), 0);
      expect(backend.documentList, hasLength(2));
    });

    test('sends only the file when the record was made on an earlier '
        'try', () async {
      await add('Note.pdf');
      backend.storage.broken = true;

      expect(await library.sync(_org), 1);
      expect(library.of(_org).single.standing, LibraryStanding.recorded);
      expect(backend.documentList.single['upload_status'], 'pending');

      backend.storage.broken = false;
      expect(await library.sync(_org), 0);
      expect(backend.sent(_documents), hasLength(1));
      expect(backend.documentList.single['upload_status'], 'uploaded');
    });

    test('learns that the record was made when the answer was never '
        'heard', () async {
      final item = await add('Note.pdf');
      // The account has the record; the phone was never told.
      backend.documentList = [
        {
          ...backend.documentList.firstOrNull ?? const {},
          'id': item.id,
          'organization_id': _org,
          'owner_id': backend.documentOwnerId,
          'file_name': 'Note.pdf',
          'mime_type': 'application/pdf',
          'size_bytes': item.sizeBytes,
          'page_count': 2,
          'source': 'camera_scan',
          'storage_mode': 'cloud',
          'upload_status': 'pending',
          'checksum_sha256': null,
          'tags': <String>[],
          'shared': false,
          'has_ocr_text': false,
          'source_printer_id': null,
          'retention_expires_at': null,
          'created_at': '2026-10-10T09:00:00Z',
          'updated_at': '2026-10-10T09:00:00Z',
        },
      ];

      expect(await library.sync(_org), 1);
      expect(library.of(_org).single.standing, LibraryStanding.recorded);
      expect(await library.sync(_org), 0);
      expect(backend.documentList.single['upload_status'], 'uploaded');
    });

    test('learns that the file arrived when the answer was never '
        'heard', () async {
      await add('Note.pdf');
      backend.storage.broken = true;
      await library.sync(_org);
      // It arrived after all.
      backend.documentList = [
        {...backend.documentList.single, 'upload_status': 'uploaded'},
      ];

      expect(await library.sync(_org), 0);
      expect(library.of(_org).single.synced, isTrue);
    });

    test('marks what the workspace will not take, and goes on to the '
        'rest', () async {
      await add('Note.pdf');
      backend.fail(_documents, 403, 'document.cloud_storage_disabled');

      expect(await library.sync(_org), 1);

      final item = library.of(_org).single;
      expect(item.refused, isTrue);
      expect(item.synced, isFalse);
      expect(library.lastSynced(_org), isNull);

      // Tried again when the workspace changes its mind.
      backend.routes.clear();
      expect(await library.sync(_org), 0);
    });

    test('drops what has lost its file', () async {
      final item = await add('Note.pdf');
      File(item.path).deleteSync();

      expect(await library.sync(_org), 0);

      expect(library.of(_org), isEmpty);
      expect(backend.sent(_documents), isEmpty);
    });

    test('runs one pass at a time', () async {
      await add('Note.pdf');

      final passes = await Future.wait([
        library.sync(_org),
        library.sync(_org),
      ]);

      expect(passes, [0, 0]);
      expect(backend.sent(_documents), hasLength(1));
    });
  });

  group('keeper', () {
    test('keeps a file and sends it at once', () async {
      final keep = library.keeper(_org);

      final kept = await keep(
        made('Note.pdf'),
        mimeType: 'application/pdf',
        pageCount: 1,
        text: 'Hello',
      );

      expect(kept!.synced, isTrue);
      expect(kept.source, 'upload');
      expect(backend.documentList.single['file_name'], 'Note.pdf');
    });

    test('keeps it on the phone when the account cannot be '
        'reached', () async {
      backend.offline = true;

      final kept = await library.keeper(_org)(
        made('Note.pdf'),
        mimeType: 'application/pdf',
        source: 'printer_scan',
        printerId: 'printer-1',
      );

      expect(kept!.synced, isFalse);
      expect(kept.printerId, 'printer-1');
      expect(library.waiting(_org), 1);
    });

    test('says so when the phone has no room for it', () async {
      // Where it would be put is a file, not a folder.
      File(folder.path).writeAsStringSync('in the way');

      final kept = await library.keeper(_org)(
        made('Note.pdf'),
        mimeType: 'application/pdf',
      );

      expect(kept, isNull);
    });
  });

  test('renames what it has, and leaves alone what it has not', () async {
    final item = await add('Note.pdf');

    await library.rename(item.id, 'List.pdf');
    await library.rename('unknown', 'Nothing.pdf');

    expect(library.of(_org).single.name, 'List.pdf');
    // The file stays where it was.
    expect(library.fileOf(item.id)!.path, item.path);
  });

  test('removes what it has, with its file', () async {
    final item = await add('Note.pdf');
    final other = await add('Other.pdf');

    await library.remove(item.id);
    await library.remove('unknown');

    expect(library.of(_org), [other]);
    expect(File(item.path).existsSync(), isFalse);
    expect(File(other.path).existsSync(), isTrue);

    // Gone already: nothing to clear away.
    File(other.path).parent.deleteSync(recursive: true);
    await library.remove(other.id);
    expect(library.of(_org), isEmpty);
  });

  group('LibraryItem', () {
    test('goes to and from what is written down', () async {
      final item = (await add(
        'Note.pdf',
        text: 'Hello',
      )).copyWith(standing: LibraryStanding.recorded, refused: true);

      final read = LibraryItem.fromJson(
        jsonDecode(jsonEncode(item.toJson())) as Map<String, dynamic>,
      );

      expect(read, item);
    });

    test('changes one thing at a time', () async {
      final item = await add('Note.pdf');

      expect(item.copyWith(), item);
      expect(item.copyWith(name: 'List.pdf').path, item.path);
      expect(item.copyWith(path: '/elsewhere').name, 'Note.pdf');
    });

    test('is listed as a document, in the account only once it is '
        'there', () async {
      final item = await add('Note.pdf');

      final waiting = item.asDocument;
      expect(waiting.id, item.id);
      expect(waiting.name, 'Note.pdf');
      expect(waiting.pageCount, 2);
      expect(waiting.source, 'camera_scan');
      expect(waiting.inCloud, isFalse);
      expect(waiting.canFetch, isFalse);

      final recorded = item
          .copyWith(standing: LibraryStanding.recorded)
          .asDocument;
      expect(recorded.awaitsFile, isTrue);

      final synced = item.copyWith(standing: LibraryStanding.synced).asDocument;
      expect(synced.canFetch, isTrue);
    });
  });
}
