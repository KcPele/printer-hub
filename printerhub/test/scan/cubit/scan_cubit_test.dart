import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:printerhub/scan/scan.dart';
import 'package:printers_repository/printers_repository.dart';

import '../../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';

void main() {
  late TestBackend backend;
  final printer = PrinterRead.fromJson(printerBody().cast());

  setUp(() async {
    backend = TestBackend()
      ..printerList = [printerBody()]
      ..plugInPrinter();
    await backend.signedInBefore();
  });
  tearDown(() => backend.close());

  ScanCubit build({PrinterRead? on, Directory? directory}) {
    final cubit = ScanCubit(
      printersRepository: backend.printers,
      jobsRepository: backend.jobs,
      documentsRepository: backend.documentsKept,
      sharer: backend.sharer,
      organizationId: _org,
      printer: on ?? printer,
      name: 'Scan today',
      directory: directory ?? backend.scans,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  /// The printer with its scanner changed by [change].
  PrinterRead scanner(Map<String, Object?> change) {
    final body = printerBody();
    final capabilities = body['capabilities']! as Map<String, Object?>;
    return PrinterRead.fromJson(
      {
        ...body,
        'capabilities': {
          ...capabilities,
          'scan': {...capabilities['scan']! as Map<String, Object?>, ...change},
        },
      }.cast(),
    );
  }

  List<String> recorded(Map<String, Object?> job) => [
    for (final event in backend.jobEvents[job['id']]!)
      event['status'] as String,
  ];

  test('starts with the scanner’s usual choices, and a name', () {
    final cubit = build();

    expect(cubit.state.step, ScanStep.choosing);
    expect(cubit.state.name, 'Scan today');
    expect(cubit.state.choices, const ScanChoices());
    expect(cubit.state.pages, isEmpty);
  });

  group('choices', () {
    test('are fitted to what the scanner offers', () {
      final small = scanner({
        'sources': ['adf'],
        'color_modes': ['grayscale'],
        'resolutions_dpi': [200, 400],
        'adf_duplex': false,
        'max_width_mm': 150.0,
        'max_height_mm': 212.0,
      });

      final fitted = ScanCubit.fitted(
        const ScanChoices(duplex: true, resolutionDpi: 350),
        small,
      );

      expect(fitted.source, 'adf');
      expect(fitted.color, 'grayscale');
      expect(fitted.duplex, isFalse);
      expect(fitted.resolutionDpi, 400);
      expect(fitted.mediaSize, 'iso_a5_148x210mm');
    });

    test('keep what the scanner does offer', () {
      const wanted = ScanChoices(
        source: 'adf',
        color: 'grayscale',
        duplex: true,
        resolutionDpi: 600,
        mediaSize: 'iso_a5_148x210mm',
      );

      expect(ScanCubit.fitted(wanted, printer), wanted);
    });

    test('scan both sides only from the feeder', () {
      expect(
        ScanCubit.fitted(const ScanChoices(duplex: true), printer).duplex,
        isFalse,
      );
    });

    test('are left alone on a scanner that has not said what it offers, or '
        'is too small for any paper the app knows', () {
      final unknown = PrinterRead.fromJson(
        {...printerBody(), 'capabilities': null}.cast(),
      );
      final tiny = scanner({'max_width_mm': 50.0, 'max_height_mm': 80.0});
      final vague = scanner({
        'sources': <String>[],
        'color_modes': <String>[],
        'resolutions_dpi': <int>[],
      });
      const wanted = ScanChoices(source: 'adf', resolutionDpi: 123);

      expect(ScanCubit.fitted(wanted, unknown), wanted);
      expect(ScanCubit.fitted(wanted, vague).resolutionDpi, 123);
      expect(ScanCubit.fitted(wanted, vague).source, 'adf');
      expect(ScanCubit.fitted(wanted, tiny).mediaSize, isNull);
    });

    test('change, and so does the name', () {
      final cubit = build()
        ..change(const ScanChoices(source: 'adf', duplex: true))
        ..rename('Contract');

      expect(cubit.state.choices.source, 'adf');
      expect(cubit.state.choices.duplex, isTrue);
      expect(cubit.state.name, 'Contract');
    });
  });

  group('scan', () {
    test('keeps the page, and records the job from start to end', () async {
      final cubit = build();

      await cubit.scan();

      expect(cubit.state.step, ScanStep.review);
      expect(cubit.state.failure, isNull);
      expect(cubit.state.progress, isNull);
      final page = cubit.state.pages.single;
      expect(page.mimeType, 'image/jpeg');
      expect(page.file.readAsBytesSync(), tinyJpeg);

      final job = backend.jobList.single;
      expect(job['type'], 'scan');
      expect(job['title'], 'Scan today');
      expect(job['status'], 'completed');
      expect(job['connection_id'], 'connection-escl-2');
      expect(recorded(job), ['processing', 'scanning', 'completed']);
      expect(backend.jobEvents[job['id']]!.last['page_count'], 1);
    });

    test('asks the scanner for what was chosen', () async {
      final cubit = build()
        ..change(
          const ScanChoices(
            source: 'adf',
            color: 'grayscale',
            mediaSize: 'iso_a5_148x210mm',
          ),
        );

      await cubit.scan();

      final asked = backend.scansStarted.single;
      expect(asked, contains('Feeder'));
      expect(asked, contains('<pwg:Width>1748</pwg:Width>'));
      expect(
        backend.lastBody('POST /organizations/$_org/jobs')['settings'],
        containsPair('color_mode', 'grayscale'),
      );
    });

    test('adds to the pages when run again', () async {
      backend.scanPages = [tinyJpeg, tinyJpeg];
      final cubit = build();

      await cubit.scan();
      await cubit.scan();

      expect(cubit.state.pages, hasLength(4));
      expect(backend.jobList, hasLength(2));
    });

    test('says why it stopped, with nothing scanned', () async {
      backend
        ..scannerRefuses = 409
        ..scannerFeeder = 'ScannerAdfEmpty';
      final cubit = build()..change(const ScanChoices(source: 'adf'));

      await cubit.scan();

      expect(cubit.state.step, ScanStep.choosing);
      expect(cubit.state.failure, 'scan.feeder_empty');
      final job = backend.jobList.single;
      expect(job['status'], 'failed');
      expect(job['error_code'], 'scan.feeder_empty');
    });

    test('keeps the pages from before when a later scan fails', () async {
      final cubit = build();
      await cubit.scan();
      backend.unplugPrinter();

      await cubit.scan();

      expect(cubit.state.step, ScanStep.review);
      expect(cubit.state.pages, hasLength(1));
      expect(cubit.state.failure, 'scan.unreachable');
    });

    test('scans while the API is out of reach, and syncs later', () async {
      final cubit = build();
      backend.offline = true;

      await cubit.scan();

      expect(cubit.state.pages, hasLength(1));
      expect(backend.jobList, isEmpty);

      backend.offline = false;
      expect(await backend.jobs.sync(_org), 0);
      expect(backend.jobList.single['status'], 'completed');
    });

    test('does not scan when the backend will not record it', () async {
      backend.fail('POST /organizations/$_org/jobs', 403, 'permission.denied');
      final cubit = build();

      await cubit.scan();

      expect(cubit.state.step, ScanStep.choosing);
      expect(cubit.state.error, isA<ApiProblem>());
      expect(backend.scansStarted, isEmpty);
    });

    test('is one at a time', () async {
      final cubit = build();

      final first = cubit.scan();
      await cubit.scan();
      await first;

      expect(backend.scansStarted, hasLength(1));
    });

    test('can be stopped, and keeps what arrived', () async {
      backend.scanPages = [tinyJpeg, tinyJpeg, tinyJpeg];
      final cubit = build()..change(const ScanChoices(source: 'adf'));

      final scanning = cubit.scan();
      await cubit.stream.firstWhere(
        (state) => (state.progress?.pages.length ?? 0) == 1,
      );
      await cubit.cancel();
      await scanning;

      expect(cubit.state.step, ScanStep.review);
      expect(cubit.state.pages, isNotEmpty);
      expect(cubit.state.failure, isNull);
      expect(backend.jobList.single['status'], 'cancelled');
    });

    test('stopping with nothing scanning does nothing', () async {
      final cubit = build();

      await cubit.cancel();

      expect(cubit.state.step, ScanStep.choosing);
    });

    test('finishes quietly when the screen has gone', () async {
      final cubit = build();

      final scanning = cubit.scan();
      await pumpEventQueue(times: 2);
      await cubit.close();
      await scanning;

      expect(backend.jobList.single['status'], 'completed');
    });
  });

  group('pages', () {
    Future<ScanCubit> scanned({int pages = 3}) async {
      backend.scanPages = [for (var i = 0; i < pages; i++) tinyJpeg];
      final cubit = build()..change(const ScanChoices(source: 'adf'));
      await cubit.scan();
      return cubit;
    }

    test('can be taken out, and the file goes with it', () async {
      final cubit = await scanned();
      final second = cubit.state.pages[1];

      cubit.remove(second);

      expect(cubit.state.pages, hasLength(2));
      expect(cubit.state.pages, isNot(contains(second)));
      expect(second.file.existsSync(), isFalse);
    });

    test('taking out the last goes back to the choices', () async {
      final cubit = await scanned(pages: 1);

      cubit.remove(cubit.state.pages.single);

      expect(cubit.state.step, ScanStep.choosing);
      expect(cubit.state.choices.source, 'adf');
    });

    test('can be moved', () async {
      final cubit = await scanned();
      final [first, second, third] = cubit.state.pages;

      cubit.move(0, 2);
      expect(cubit.state.pages, [second, third, first]);

      cubit.move(2, 0);
      expect(cubit.state.pages, [first, second, third]);
    });

    test('cannot be changed before there are any', () {
      final cubit = build();
      final page = ScannedPage(file: File('x.jpg'), mimeType: 'image/jpeg');

      cubit
        ..remove(page)
        ..move(0, 1)
        ..edit();

      expect(cubit.state, cubit.state);
      expect(cubit.state.step, ScanStep.choosing);
    });

    test('can be thrown away to begin again', () async {
      final cubit = await scanned();
      final files = [for (final page in cubit.state.pages) page.file];
      cubit
        ..rename('Mine')
        ..startOver();

      expect(cubit.state.step, ScanStep.choosing);
      expect(cubit.state.pages, isEmpty);
      expect(cubit.state.name, 'Mine');
      expect(cubit.state.choices.source, 'adf');
      expect(files.any((file) => file.existsSync()), isFalse);
    });
  });

  group('an ID card', () {
    test('is scanned from the corner of the glass, a side at a time, '
        'whatever else was chosen', () async {
      final cubit = build()
        ..change(
          const ScanChoices(
            source: 'adf',
            format: 'image/jpeg',
            mediaSize: 'na_letter_8.5x11in',
          ),
        )
        ..asCard(card: true);
      expect(cubit.state.card, isTrue);

      await cubit.scan();

      final asked = backend.scansStarted.single;
      expect(asked, contains('Platen'));
      // 92 mm by 60 mm, in three-hundredths of an inch.
      expect(asked, contains('<pwg:Width>1087</pwg:Width>'));
      expect(asked, contains('<pwg:Height>709</pwg:Height>'));
      final settings =
          backend.lastBody('POST /organizations/$_org/jobs')['settings']
              as Map<String, Object?>;
      expect(settings['source'], 'platen');
      expect(settings['format'], 'application/pdf');
      expect(settings['media_size'], 'iso_id-1_53.98x85.6mm');
      // What the person chose is still theirs.
      expect(cubit.state.choices.mediaSize, 'na_letter_8.5x11in');
    });

    test('waits for its back after its front', () async {
      final cubit = build()..asCard(card: true);
      expect(cubit.state.awaitsBack, isFalse);

      await cubit.scan();
      expect(cubit.state.awaitsBack, isTrue);

      await cubit.scan();
      expect(cubit.state.awaitsBack, isFalse);
      expect(cubit.state.pages, hasLength(2));
    });

    test('is one sheet of one PDF, and kept as one page', () async {
      final cubit = build()
        ..change(const ScanChoices(format: 'image/jpeg'))
        ..asCard(card: true)
        ..rename('Licence');
      await cubit.scan();
      await cubit.scan();

      await cubit.save();

      final file = cubit.state.files.single;
      expect(file.path, endsWith('/Licence.pdf'));
      expect(
        RegExp(r'/Type\s*/Page\b')
            .allMatches(String.fromCharCodes(file.readAsBytesSync())),
        hasLength(1),
      );

      await cubit.keep();
      expect(backend.documentList.single['page_count'], 1);
    });

    test('can be switched off again before the first side', () {
      final cubit = build()
        ..asCard(card: true)
        ..asCard(card: false);

      expect(cubit.state.card, isFalse);
    });

    test('is chosen before the first page, not after', () async {
      final cubit = build();
      await cubit.scan();

      cubit.asCard(card: true);

      expect(cubit.state.card, isFalse);
    });

    test('stays chosen when beginning again', () async {
      final cubit = build()..asCard(card: true);
      await cubit.scan();

      cubit.startOver();

      expect(cubit.state.card, isTrue);
      expect(cubit.state.pages, isEmpty);
    });

    test('needs a glass to lay it on', () {
      final feederOnly = scanner({
        'sources': ['adf'],
      });
      final unknown = PrinterRead.fromJson(
        {...printerBody(), 'capabilities': null}.cast(),
      );

      expect(ScanCubit.takesCards(printer), isTrue);
      expect(ScanCubit.takesCards(unknown), isTrue);
      expect(ScanCubit.takesCards(feederOnly), isFalse);
      final cubit = build(on: feederOnly)..asCard(card: true);
      expect(cubit.state.card, isFalse);
    });
  });

  group('save', () {
    test('puts the pages together as one PDF', () async {
      backend.scanPages = [tinyJpeg, tinyJpeg];
      final cubit = build()..rename('Receipts');
      await cubit.scan();

      await cubit.save();

      expect(cubit.state.step, ScanStep.saved);
      final file = cubit.state.files.single;
      expect(file.path, endsWith('/Receipts.pdf'));
      expect(String.fromCharCodes(file.readAsBytesSync().take(5)), '%PDF-');
    });

    test('keeps pictures when that was asked for', () async {
      final cubit = build()..change(const ScanChoices(format: 'image/jpeg'));
      await cubit.scan();

      await cubit.save();

      expect(cubit.state.files.single.path, endsWith('/Scan today.jpg'));
    });

    test('does nothing before there are pages', () async {
      final cubit = build();

      await cubit.save();
      await cubit.share();

      expect(cubit.state.step, ScanStep.choosing);
      expect(backend.sharer.shared, isEmpty);
    });

    test('says when the scan cannot be kept', () async {
      final cubit = build(
        directory: Directory('${backend.scans.path}/missing'),
      );
      await cubit.scan();

      await cubit.save();

      expect(cubit.state.step, ScanStep.review);
      expect(cubit.state.failure, 'scan.storage');
    });

    test('says nothing once the screen has gone', () async {
      final cubit = build();
      await cubit.scan();
      final saving = cubit.save();
      await cubit.close();
      await expectLater(saving, completes);

      final other = build(
        directory: Directory('${backend.scans.path}/missing'),
      );
      await other.scan();
      final failing = other.save();
      await other.close();
      await expectLater(failing, completes);
    });

    test('hands the finished scan to the share sheet', () async {
      final cubit = build();
      await cubit.scan();
      await cubit.save();

      await cubit.share();

      final shared = backend.sharer.shared.single;
      expect(shared.name, 'Scan today');
      expect(shared.files.single.path, cubit.state.files.single.path);
    });

    test('goes back to the pages, and drops the file', () async {
      final cubit = build();
      await cubit.scan();
      await cubit.save();
      final file = cubit.state.files.single;

      cubit.edit();

      expect(cubit.state.step, ScanStep.review);
      expect(cubit.state.files, isEmpty);
      expect(file.existsSync(), isFalse);
      expect(cubit.state.pages.single.file.existsSync(), isTrue);
    });

    test('begins again from a saved scan, and drops everything', () async {
      final cubit = build();
      await cubit.scan();
      await cubit.save();
      final file = cubit.state.files.single;

      cubit.startOver();

      expect(cubit.state.step, ScanStep.choosing);
      expect(file.existsSync(), isFalse);
    });

    group('in the workspace', () {
      const documents = 'POST /organizations/$_org/documents';

      Future<ScanCubit> saved({
        int pages = 1,
        ScanChoices choices = const ScanChoices(),
      }) async {
        backend.scanPages = [for (var i = 0; i < pages; i++) tinyJpeg];
        final cubit = build()
          ..change(choices)
          ..rename('Receipts');
        await cubit.scan();
        await cubit.save();
        return cubit;
      }

      test('keeps the scan, with what is known of it', () async {
        final cubit = await saved(
          pages: 2,
          choices: const ScanChoices(source: 'adf'),
        );

        await cubit.keep();

        expect(cubit.state.kept, ScanKept.yes);
        expect(cubit.state.step, ScanStep.saved);
        final document = backend.documentList.single;
        expect(document['file_name'], 'Receipts.pdf');
        expect(document['mime_type'], 'application/pdf');
        expect(document['page_count'], 2);
        expect(document['source_printer_id'], 'printer-1');
        expect(document['upload_status'], 'uploaded');
        expect(
          backend.storage.stored['/${document['id']}'],
          cubit.state.files.single.readAsBytesSync(),
        );
      });

      test('keeps each picture as a document of one page', () async {
        final cubit = await saved(
          pages: 2,
          choices: const ScanChoices(source: 'adf', format: 'image/jpeg'),
        );

        await cubit.keep();

        expect(backend.documentList.map((d) => d['file_name']).toSet(), {
          'Receipts 1.jpg',
          'Receipts 2.jpg',
        });
        expect(backend.documentList.map((d) => d['mime_type']).toSet(), {
          'image/jpeg',
        });
        expect(backend.documentList.map((d) => d['page_count']).toSet(), {1});
      });

      test('is asked for once', () async {
        final cubit = await saved();

        final first = cubit.keep();
        await cubit.keep();
        await first;
        await cubit.keep();

        expect(backend.sent(documents), hasLength(1));
      });

      test('says why the workspace will not have it', () async {
        backend.fail(documents, 403, 'document.cloud_storage_disabled');
        final cubit = await saved();

        await cubit.keep();

        expect(cubit.state.kept, ScanKept.no);
        expect(cubit.state.error, isA<ApiProblem>());
        expect(cubit.state.files, hasLength(1));
      });

      test('sends only what did not arrive when asked again', () async {
        final cubit = await saved(
          pages: 2,
          choices: const ScanChoices(source: 'adf', format: 'image/jpeg'),
        );
        backend.storage.broken = true;

        await cubit.keep();
        expect(cubit.state.kept, ScanKept.no);
        expect(cubit.state.failure, 'scan.keep_interrupted');
        expect(backend.documentList, hasLength(1));

        backend.storage.broken = false;
        await cubit.keep();

        expect(cubit.state.kept, ScanKept.yes);
        expect(cubit.state.failure, isNull);
        // The record made the first time was finished, not made again.
        expect(backend.documentList, hasLength(2));
        expect(backend.sent(documents), hasLength(2));
        expect(backend.documentList.map((d) => d['upload_status']).toSet(), {
          'uploaded',
        });
      });

      test('cannot be asked for before the scan is saved', () async {
        final cubit = build();
        await cubit.scan();

        await cubit.keep();

        expect(backend.documentList, isEmpty);
      });

      test('nothing else changes while it is on its way', () async {
        final cubit = await saved();

        final keeping = cubit.keep();
        cubit
          ..edit()
          ..startOver();
        await keeping;

        expect(cubit.state.step, ScanStep.saved);
        expect(cubit.state.kept, ScanKept.yes);
      });

      test('says nothing once the screen has gone', () async {
        for (final setUp in <void Function()>[
          () {},
          () => backend.storage.broken = true,
          () => backend.fail(documents, 403, 'permission.denied'),
        ]) {
          backend.storage.broken = false;
          backend.routes.clear();
          final cubit = await saved();
          setUp();
          final keeping = cubit.keep();
          await cubit.close();
          await expectLater(keeping, completes);
        }
      });
    });

    test('nothing changes while the pages are being put together', () async {
      final cubit = build();
      await cubit.scan();

      final saving = cubit.save();
      cubit
        ..startOver()
        ..rename('Late')
        ..change(const ScanChoices(source: 'adf'));
      await saving;

      expect(cubit.state.step, ScanStep.saved);
      expect(cubit.state.name, 'Scan today');
      expect(cubit.state.choices.source, 'platen');
    });
  });
}
