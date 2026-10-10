import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:documents_repository/documents_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/documents/documents.dart';
import 'package:printerhub/library/library_item.dart';

import '../../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';
const _documents = '/organizations/$_org/documents';

void main() {
  late TestBackend backend;

  setUp(() async {
    backend = TestBackend()
      ..documentList = [
        documentBody(id: 'document-3', name: 'Contract.pdf'),
        documentBody(id: 'document-2', name: 'Receipts October.pdf'),
        documentBody(),
      ];
    backend.storage.stored['/document-3'] = '%PDF a contract'.codeUnits;
    await backend.signedInBefore();
  });
  tearDown(() => backend.close());

  DocumentsCubit build() => DocumentsCubit(
    documentsRepository: backend.documentsKept,
    library: backend.library,
    sharer: backend.sharer,
    organizationId: _org,
  );

  Future<DocumentsCubit> loaded() async {
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.load();
    return cubit;
  }

  List<String> names(DocumentsState state) => [
    for (final document in state.documents) document.name,
  ];

  test('starts by reading', () {
    final cubit = build();
    addTearDown(cubit.close);

    expect(cubit.state, const DocumentsState());
  });

  blocTest<DocumentsCubit, DocumentsState>(
    'lists the documents, newest first',
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => [
      const DocumentsState(),
      isA<DocumentsState>()
          .having((s) => s.status, 'status', DocumentsStatus.ready)
          .having(names, 'names', [
            'Contract.pdf',
            'Receipts October.pdf',
            'Receipts.pdf',
          ])
          .having((s) => s.next, 'next', isNull),
    ],
  );

  blocTest<DocumentsCubit, DocumentsState>(
    'searches by name',
    build: build,
    act: (cubit) => cubit.search('receipts'),
    expect: () => [
      const DocumentsState(query: 'receipts'),
      isA<DocumentsState>().having((s) => s.query, 'query', 'receipts').having(
        names,
        'names',
        ['Receipts October.pdf', 'Receipts.pdf'],
      ),
    ],
  );

  blocTest<DocumentsCubit, DocumentsState>(
    'says why the list cannot be read, and keeps what was searched for',
    setUp: () => backend.fail('GET $_documents', 500, 'server.error'),
    build: build,
    act: (cubit) => cubit.search('receipts'),
    skip: 1,
    expect: () => [
      isA<DocumentsState>()
          .having((s) => s.status, 'status', DocumentsStatus.failed)
          .having((s) => s.query, 'query', 'receipts')
          .having((s) => s.error, 'error', isA<ApiProblem>()),
    ],
  );

  group('what was made on this phone', () {
    /// Something a tool made, kept on the phone and not yet sent.
    Future<LibraryItem> made(String name, {String? text}) {
      final file = File('${backend.scans.path}/$name')
        ..writeAsStringSync('%PDF made here');
      return backend.library.add(
        organizationId: _org,
        file: file,
        mimeType: 'application/pdf',
        text: text,
      );
    }

    test('comes first while it waits to be sent, and opens with no '
        'network', () async {
      final note = await made('Note.pdf');
      final cubit = await loaded();

      expect(names(cubit.state).first, 'Note.pdf');
      expect(names(cubit.state), hasLength(4));
      expect(cubit.state.waiting, {note.id});
      expect(cubit.state.onPhone, {note.id});
      expect(cubit.state.offline, isFalse);
      final document = cubit.state.documents.first;
      expect(document.canFetch, isFalse);
      expect(cubit.state.canOpen(document), isTrue);
      expect(cubit.state.canOpen(cubit.state.documents.last), isTrue);

      backend.offline = true;
      final file = await cubit.fetch(document);
      expect(file!.path, note.path);
      await cubit.open(document);
      expect(backend.sharer.shared.single.files.single.path, note.path);
    });

    test('is listed once after it reaches the account', () async {
      final note = await made('Note.pdf');
      final cubit = await loaded();

      await backend.library.sync(_org);
      await pumpEventQueue();

      // The list was read again by itself.
      expect(names(cubit.state).where((name) => name == 'Note.pdf'), [
        'Note.pdf',
      ]);
      expect(cubit.state.waiting, isEmpty);
      expect(cubit.state.onPhone, {note.id});
      expect(cubit.state.documents.first.canFetch, isTrue);
    });

    test('is all there is to see when the account cannot be '
        'reached', () async {
      await made('Note.pdf', text: 'Buy toner');
      final receipts = await made('Receipts.pdf');
      await backend.library.sync(_org);
      await made('Later.pdf');
      backend.offline = true;

      final cubit = await loaded();

      expect(cubit.state.status, DocumentsStatus.ready);
      expect(cubit.state.offline, isTrue);
      expect(names(cubit.state), ['Later.pdf', 'Receipts.pdf', 'Note.pdf']);
      expect(cubit.state.waiting, hasLength(1));
      expect(cubit.state.onPhone, hasLength(3));

      // Found by its name, or by what it says.
      await cubit.search('RECEIPTS');
      expect(names(cubit.state), ['Receipts.pdf']);
      expect(cubit.state.documents.single.id, receipts.id);
      await cubit.search('toner');
      expect(names(cubit.state), ['Note.pdf']);
    });

    test('is renamed and deleted on the phone while it waits', () async {
      final note = await made('Note.pdf');
      final cubit = await loaded();

      await cubit.rename(cubit.state.documents.first, 'List.pdf');
      expect(names(cubit.state).first, 'List.pdf');
      expect(backend.library.of(_org).single.name, 'List.pdf');
      expect(backend.sent('PATCH $_documents/${note.id}'), isEmpty);

      await cubit.remove(cubit.state.documents.first);
      expect(names(cubit.state), hasLength(3));
      expect(backend.library.of(_org), isEmpty);
      expect(backend.sent('DELETE $_documents/${note.id}'), isEmpty);
    });

    test('is renamed and deleted in the account too once it is '
        'there', () async {
      final note = await made('Note.pdf');
      await backend.library.sync(_org);
      final cubit = await loaded();
      final document = cubit.state.documents.first;

      await cubit.rename(document, 'List.pdf');
      expect(backend.library.of(_org).single.name, 'List.pdf');
      expect(backend.sent('PATCH $_documents/${note.id}'), hasLength(1));

      await cubit.remove(cubit.state.documents.first);
      expect(backend.library.of(_org), isEmpty);
      expect(backend.documentList, hasLength(3));
    });

    test('does not read the list again while a change is being '
        'made', () async {
      await made('Note.pdf');
      final cubit = await loaded();
      final reads = backend.sent('GET $_documents').length;

      final renaming = cubit.rename(cubit.state.documents.first, 'List.pdf');
      await made('Other.pdf');
      await renaming;

      expect(backend.sent('GET $_documents'), hasLength(reads));
    });
  });

  group('sharing', () {
    test('lets the workspace see a document, and takes it back', () async {
      final cubit = await loaded();
      final document = cubit.state.documents.first;
      expect(document.shared, isFalse);

      await cubit.share(document, shared: true);
      expect(cubit.state.documents.first.shared, isTrue);
      expect(backend.lastBody('PATCH $_documents/document-3'), {
        'shared': true,
      });

      await cubit.share(cubit.state.documents.first, shared: false);
      expect(cubit.state.documents.first.shared, isFalse);
    });

    test('says why it could not be', () async {
      backend.fail('PATCH $_documents/document-3', 403, 'permission.denied');
      final cubit = await loaded();

      await cubit.share(cubit.state.documents.first, shared: true);

      expect(cubit.state.error, isA<ApiProblem>());
      expect(cubit.state.documents.first.shared, isFalse);
    });
  });

  test('drops an answer that a newer search has overtaken', () async {
    final cubit = build();
    addTearDown(cubit.close);

    final slow = cubit.load();
    await cubit.search('contract');
    await slow;

    expect(names(cubit.state), ['Contract.pdf']);

    backend.offline = true;
    final failing = cubit.load();
    backend.offline = false;
    await cubit.search('contract');
    await failing;
    expect(cubit.state.status, DocumentsStatus.ready);
  });

  test('says nothing once the screen has gone', () async {
    final cubit = build();
    final loading = cubit.load();
    await cubit.close();
    await expectLater(loading, completes);

    backend.offline = true;
    final other = build();
    final failing = other.load();
    await other.close();
    await expectLater(failing, completes);

    backend
      ..offline = false
      ..fail('GET $_documents', 500, 'server.error');
    final refused = build();
    final refusing = refused.load();
    await refused.close();
    await expectLater(refusing, completes);
  });

  group('more', () {
    setUp(() => backend.documentPageSize = 2);

    test('reads on, a page at a time', () async {
      final cubit = await loaded();
      expect(names(cubit.state), hasLength(2));
      expect(cubit.state.next, '2');

      final first = cubit.more();
      // One page is asked for at a time.
      await cubit.more();
      await first;

      expect(names(cubit.state), hasLength(3));
      expect(cubit.state.next, isNull);
      expect(cubit.state.loadingMore, isFalse);
      expect(backend.sent('GET $_documents'), hasLength(2));

      // There is no more after that.
      await cubit.more();
      expect(backend.sent('GET $_documents'), hasLength(2));
    });

    test('keeps what it has when the next page cannot be read', () async {
      final cubit = await loaded();
      backend.offline = true;

      await cubit.more();

      expect(names(cubit.state), hasLength(2));
      expect(cubit.state.error, isA<ApiUnreachable>());
      expect(cubit.state.next, '2');
    });

    test('drops a page a new search has overtaken, and one for a screen '
        'that has gone', () async {
      final cubit = await loaded();

      final page = cubit.more();
      await cubit.search('contract');
      await page;
      expect(names(cubit.state), ['Contract.pdf']);

      backend.documentPageSize = 1;
      await cubit.load();
      backend.offline = true;
      final failing = cubit.more();
      backend.offline = false;
      await cubit.search('contract');
      await failing;
      expect(cubit.state.error, isNull);

      final other = build();
      await other.load();
      final late = other.more();
      await other.close();
      await expectLater(late, completes);
    });
  });

  group('open', () {
    test('fetches the file and hands it to the share sheet', () async {
      final cubit = await loaded();
      final contract = cubit.state.documents.first;

      final opening = cubit.open(contract);
      expect(cubit.state.busyId, 'document-3');
      await opening;

      expect(cubit.state.busyId, isNull);
      final shared = backend.sharer.shared.single;
      expect(shared.name, 'Contract.pdf');
      expect(shared.files.single.readAsStringSync(), '%PDF a contract');
    });

    test('fetches the file alone, to print it', () async {
      final cubit = await loaded();

      final file = await cubit.fetch(cubit.state.documents.first);

      expect(file!.readAsStringSync(), '%PDF a contract');
      expect(cubit.state.busyId, isNull);
      expect(backend.sharer.shared, isEmpty);
    });

    test('says when the file cannot be fetched', () async {
      final cubit = await loaded();

      // Nothing was ever stored for this one.
      await cubit.open(cubit.state.documents.last);

      expect(cubit.state.fetchFailed, isTrue);
      expect(cubit.state.busyId, isNull);
      expect(backend.sharer.shared, isEmpty);
    });

    test('says why the workspace will not give the file', () async {
      final cubit = await loaded();
      backend.fail(
        'GET $_documents/document-3/download-url',
        403,
        'permission.denied',
      );

      await cubit.open(cubit.state.documents.first);

      expect(cubit.state.error, isA<ApiProblem>());
      expect(cubit.state.fetchFailed, isFalse);
    });

    test('is not tried for a document whose file is elsewhere, or while '
        'another is being fetched', () async {
      backend.documentList = [
        documentBody(storageMode: 'local', uploadStatus: 'not_applicable'),
        ...backend.documentList,
      ];
      final cubit = await loaded();
      final [local, contract, ...] = cubit.state.documents;

      await cubit.open(local);
      expect(backend.sent('GET $_documents/document-1/download-url'), isEmpty);

      final first = cubit.open(contract);
      await cubit.open(contract);
      await first;
      expect(backend.sharer.shared, hasLength(1));
    });

    test('says nothing once the screen has gone', () async {
      for (final arrange in <void Function()>[
        () {},
        () => backend.storage.broken = true,
        () => backend.fail(
          'GET $_documents/document-3/download-url',
          403,
          'permission.denied',
        ),
      ]) {
        backend.storage.broken = false;
        backend.routes.clear();
        final cubit = build();
        await cubit.load();
        arrange();
        final opening = cubit.open(cubit.state.documents.first);
        await cubit.close();
        await expectLater(opening, completes);
      }
      expect(backend.sharer.shared, isEmpty);
    });
  });

  group('changes', () {
    test('rename a document in place', () async {
      final cubit = await loaded();

      await cubit.rename(cubit.state.documents[1], 'October.pdf');

      expect(names(cubit.state), [
        'Contract.pdf',
        'October.pdf',
        'Receipts.pdf',
      ]);
      expect(backend.documentList[1]['file_name'], 'October.pdf');
      expect(cubit.state.busyId, isNull);
    });

    test('delete a document', () async {
      final cubit = await loaded();

      await cubit.remove(cubit.state.documents.first);

      expect(names(cubit.state), ['Receipts October.pdf', 'Receipts.pdf']);
      expect(backend.documentList, hasLength(2));
    });

    test('say why they could not be made, and leave the list', () async {
      final cubit = await loaded();
      backend.fail('DELETE $_documents/document-3', 403, 'permission.denied');

      await cubit.remove(cubit.state.documents.first);

      expect(cubit.state.error, isA<ApiProblem>());
      expect(names(cubit.state), hasLength(3));
      expect(cubit.state.busyId, isNull);
    });

    test('are made one at a time', () async {
      final cubit = await loaded();
      final [contract, october, _] = cubit.state.documents;

      final first = cubit.remove(contract);
      await cubit.remove(october);
      await first;

      expect(backend.documentList, hasLength(2));
    });

    test('say nothing once the screen has gone', () async {
      final cubit = build();
      await cubit.load();
      final removing = cubit.remove(cubit.state.documents.first);
      await cubit.close();
      await expectLater(removing, completes);

      backend.fail('DELETE $_documents/document-2', 403, 'permission.denied');
      final other = build();
      await other.load();
      final failing = other.remove(other.state.documents.first);
      await other.close();
      await expectLater(failing, completes);
    });
  });

  test('a document in the list compares by value', () {
    final a = StoredDocument.fromApi(
      DocumentRead.fromJson(documentBody().cast()),
    );
    final b = StoredDocument.fromApi(
      DocumentRead.fromJson(documentBody().cast()),
    );

    expect(a, b);
  });
}
