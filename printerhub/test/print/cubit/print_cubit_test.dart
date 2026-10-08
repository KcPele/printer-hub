import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:printer_protocols/printer_protocols.dart';
import 'package:printerhub/print/print.dart';
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

  PrintCubit build() => PrintCubit(
    printersRepository: backend.printers,
    jobsRepository: backend.jobs,
    documents: backend.documents,
    organizationId: _org,
    printer: printer,
  );

  TypeMatcher<PrintState> on(PrintStep step) =>
      isA<PrintState>().having((s) => s.step, 'step', step);

  List<String> recorded() => [
    for (final event in backend.jobEvents.values.single)
      event['status'] as String,
  ];

  test('starts with nothing chosen', () {
    final cubit = build();
    addTearDown(cubit.close);

    expect(cubit.state, const PrintState());
    expect(cubit.state.step, PrintStep.choosing);
    expect(cubit.state.canUseSystemPrint, isFalse);
  });

  group('choose', () {
    blocTest<PrintCubit, PrintState>(
      'reads the chosen file',
      build: build,
      act: (cubit) => cubit.choose(),
      expect: () => [
        on(PrintStep.reading)
            .having((s) => s.document!.name, 'name', 'Report.pdf'),
        on(PrintStep.ready)
            .having((s) => s.preview!.pageCount, 'pages', 2)
            .having((s) => s.choices, 'choices', const PrintChoices()),
      ],
    );

    blocTest<PrintCubit, PrintState>(
      'does nothing when nothing is chosen',
      setUp: () => backend.picker.next = null,
      build: build,
      act: (cubit) => cubit.choose(),
      expect: () => <PrintState>[],
    );

    blocTest<PrintCubit, PrintState>(
      'says when the file is a kind it does not print',
      setUp: () => backend.picker.next = pickedPdf(name: 'Budget.xlsx'),
      build: build,
      act: (cubit) => cubit.choose(),
      expect: () => [const PrintState(problem: PrintProblem.unsupportedFile)],
    );

    blocTest<PrintCubit, PrintState>(
      'says when the file cannot be read',
      setUp: () => backend.renderer.unreadable = true,
      build: build,
      act: (cubit) => cubit.choose(),
      skip: 1,
      expect: () => [const PrintState(problem: PrintProblem.unreadableFile)],
    );

    blocTest<PrintCubit, PrintState>(
      'keeps the choices when another file is chosen',
      build: build,
      act: (cubit) async {
        await cubit.choose();
        cubit.change(const PrintChoices(copies: 3));
        backend.picker.next = pickedPdf(name: 'Photo.jpg');
        await cubit.choose();
      },
      skip: 4,
      expect: () => [
        on(PrintStep.ready)
            .having((s) => s.document!.mimeType, 'type', 'image/jpeg')
            .having((s) => s.choices.copies, 'copies', 3),
      ],
    );

    test('does not open the file browser while a file is being read', () async {
      final cubit = build();
      addTearDown(cubit.close);

      final first = cubit.choose();
      await cubit.choose();
      await first;

      expect(backend.picker.opened, 1);
    });

    test('says nothing once the screen has gone', () async {
      final cubit = build();
      final choosing = cubit.choose();
      await cubit.close();

      await choosing;

      expect(cubit.state.step, PrintStep.choosing);
    });
  });

  test('choices only change once there is a document', () async {
    final cubit = build();
    addTearDown(cubit.close);

    cubit.change(const PrintChoices(copies: 5));
    expect(cubit.state.choices.copies, 1);

    await cubit.choose();
    cubit.change(const PrintChoices(copies: 5));
    expect(cubit.state.choices.copies, 5);
  });

  group('print', () {
    test('sends the document, follows it, and keeps its record', () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.choose();
      cubit.change(
        const PrintChoices(copies: 2, color: 'monochrome', pageRanges: '1'),
      );

      await cubit.print();

      expect(cubit.state.step, PrintStep.finished);
      expect(cubit.state.progress!.stage, PrintStage.completed);
      // The printer got the file, named so it can be found again.
      final sent = backend.printed.single;
      expect(String.fromCharCodes(sent.data), '%PDF-1.7 a report');
      final jobName =
          sent.message.group(IppGroupTag.operation)!['job-name']!.first!
              as String;
      final job = backend.jobList.single;
      expect(jobName, 'Report.pdf [${(job['id']! as String).substring(0, 8)}]');
      expect(sent.message.group(IppGroupTag.job)!['copies']!.first, 2);
      // The backend has the job, how it was to be printed, and how it went.
      expect(job['title'], 'Report.pdf');
      expect(job['page_count'], 2);
      expect((job['settings']! as Map)['copies'], 2);
      expect(job['status'], 'completed');
      expect(job['connection_id'], 'connection-ipp-1');
      expect(recorded(), ['processing', 'printing', 'completed']);
      expect(backend.jobEvents.values.single[1]['printer_job_ref'], '1');
    });

    test('draws the pages for a printer that does not read the file', () async {
      backend.plugInPrinter(formats: const ['image/pwg-raster']);
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.choose();

      await cubit.print();

      expect(cubit.state.progress!.stage, PrintStage.completed);
      expect(backend.renderer.drawn, 2);
      expect(String.fromCharCodes(backend.printed.single.data.take(4)), 'RaS2');
    });

    test('records why a print failed', () async {
      backend.printerRefuses = IppStatus.clientErrorNotPossible;
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.choose();

      await cubit.print();

      expect(cubit.state.progress!.stage, PrintStage.failed);
      expect(recorded(), ['processing', 'failed']);
      expect(
        backend.jobList.single['error_code'],
        'ipp.client-error-not-possible',
      );
    });

    test('records each connection tried, once', () async {
      backend.unplugPrinter();
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.choose();

      await cubit.print();

      expect(cubit.state.progress!.errorCode, 'print.unreachable');
      expect(recorded(), ['processing', 'failed']);
    });

    test('prints while the API is out of reach, and syncs later', () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.choose();
      backend.offline = true;

      await cubit.print();

      expect(cubit.state.progress!.stage, PrintStage.completed);
      expect(backend.printed, hasLength(1));
      expect(backend.jobList, isEmpty);

      backend.offline = false;
      expect(await backend.jobs.sync(_org), 0);
      expect(backend.jobList.single['status'], 'completed');
    });

    test('stays on the document when the backend will not record it', () async {
      backend.fail('POST /organizations/$_org/jobs', 403, 'permission.denied');
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.choose();

      await cubit.print();

      expect(cubit.state.step, PrintStep.ready);
      expect(cubit.state.error, isA<ApiProblem>());
      expect(backend.printed, isEmpty);
    });

    test(
      'does nothing before a document is chosen, or twice at once',
      () async {
        final cubit = build();
        addTearDown(cubit.close);

        await cubit.print();
        expect(backend.jobList, isEmpty);

        await cubit.choose();
        final first = cubit.print();
        await cubit.print();
        await first;
        expect(backend.jobList, hasLength(1));
      },
    );

    test('can be cancelled on the printer', () async {
      backend.printerJobState = 5;
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.choose();

      final printing = cubit.print();
      await cubit.stream.firstWhere(
        (state) => state.progress?.stage == PrintStage.printing,
      );
      await cubit.cancel();
      await printing;

      expect(cubit.state.progress!.stage, PrintStage.cancelled);
      expect(recorded().last, 'cancelled');
    });

    test('cancelling with nothing printing does nothing', () async {
      final cubit = build();
      addTearDown(cubit.close);

      await cubit.cancel();

      expect(cubit.state, const PrintState());
    });

    test('finishes quietly when the screen has gone', () async {
      final cubit = build();
      await cubit.choose();

      final printing = cubit.print();
      await pumpEventQueue(times: 2);
      await cubit.close();
      await printing;

      // The document still went, and its record is still kept.
      expect(backend.printed, hasLength(1));
      expect(backend.jobList.single['status'], 'completed');
    });
  });

  group('afterwards', () {
    test('goes back to the document to print it again', () async {
      final cubit = build();
      addTearDown(cubit.close);
      cubit.again();
      expect(cubit.state.step, PrintStep.choosing);

      await cubit.choose();
      await cubit.print();
      cubit.again();

      expect(cubit.state.step, PrintStep.ready);
      expect(cubit.state.progress, isNull);
      expect(cubit.state.document, isNotNull);
    });

    test(
      'offers the phone’s print dialog when the printer cannot take a PDF',
      () async {
        backend.plugInPrinter(formats: const ['application/postscript']);
        final cubit = build();
        addTearDown(cubit.close);
        await cubit.useSystemPrint();
        await cubit.choose();
        await cubit.print();
        expect(cubit.state.progress!.errorCode, 'print.format_not_supported');
        expect(cubit.state.canUseSystemPrint, isTrue);

        await cubit.useSystemPrint();

        expect(backend.renderer.systemPrinted.single.name, 'Report.pdf');
        expect(cubit.state.handedToSystem, isTrue);
        expect(cubit.state.canUseSystemPrint, isFalse);
      },
    );

    test('says so when the phone’s print dialog was dismissed', () async {
      backend
        ..plugInPrinter(formats: const ['application/postscript'])
        ..renderer.systemAccepts = false;
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.choose();
      await cubit.print();

      await cubit.useSystemPrint();

      expect(cubit.state.handedToSystem, isFalse);
      expect(cubit.state.canUseSystemPrint, isTrue);
    });

    test('does not offer it for a picture, or after another failure', () async {
      backend
        ..plugInPrinter(formats: const ['application/postscript'])
        ..picker.next = pickedPdf(name: 'Photo.png');
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.choose();
      await cubit.print();

      expect(cubit.state.canUseSystemPrint, isFalse);
    });
  });

  group('documents', () {
    test('a file is known by its ending', () {
      String? typeOf(String name) => pickedPdf(name: name).mimeType;

      expect(typeOf('a.PDF'), 'application/pdf');
      expect(typeOf('a.jpg'), 'image/jpeg');
      expect(typeOf('a.jpeg'), 'image/jpeg');
      expect(typeOf('a.png'), 'image/png');
      expect(typeOf('a.docx'), isNull);
      expect(typeOf('README'), isNull);
    });

    test('documents and previews compare by value', () {
      expect(pickedPdf(), pickedPdf());
      expect(pickedPdf(), isNot(pickedPdf(name: 'Other.pdf')));
      DocumentPreview pages(int count) => DocumentPreview(pageCount: count);
      expect(pages(2), pages(2));
      expect(pages(2), isNot(pages(3)));
    });
  });
}
