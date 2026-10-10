import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printer_protocols/printer_protocols.dart';
import 'package:printerhub/copy/copy.dart';
import 'package:printers_repository/printers_repository.dart';

import '../../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';
const _jobs = 'POST /organizations/$_org/jobs';

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

  CopyCubit build({Directory? directory}) {
    final cubit = CopyCubit(
      printersRepository: backend.printers,
      jobsRepository: backend.jobs,
      documentsRepository: backend.documentsKept,
      documents: backend.documents,
      sharer: backend.sharer,
      textReader: backend.textReader,
      camera: backend.camera,
      organizationId: _org,
      printer: printer,
      name: 'Copy today',
      directory: directory ?? backend.scans,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('starts ready to make one copy in colour from the glass', () {
    expect(build().state, const CopyState());
  });

  test('scans, then prints as many as asked, and records both', () async {
    final cubit = build()
      ..setCopies(3)
      ..setColor(color: false);

    await cubit.copy();

    expect(cubit.state.step, CopyStep.done);
    expect(cubit.state.scanned, 1);
    // The scanner was asked for the glass, and both halves for no colour.
    expect(backend.scansStarted.single, contains('Platen'));
    final asked = {
      for (final request in backend.sent(_jobs))
        (request.data as Map)['type']:
            ((request.data as Map)['settings'] as Map)['color_mode'],
    };
    expect(asked, {'scan': 'grayscale', 'print': 'monochrome'});
    // The printer got the scan as a PDF, three times over.
    final sent = backend.printed.single;
    expect(String.fromCharCodes(sent.data.take(5)), '%PDF-');
    expect(sent.message.group(IppGroupTag.job)!['copies']!.first, 3);
    // A scan and a print, each in the history under the copy's name.
    expect(
      {for (final job in backend.jobList) job['type']: job['status']},
      {'scan': 'completed', 'print': 'completed'},
    );
    expect(
      backend.jobList.map((job) => job['title']),
      everyElement(startsWith('Copy today')),
    );
  });

  test('takes every sheet from the feeder', () async {
    backend.scanPages = [tinyJpeg, tinyJpeg, tinyJpeg];
    final cubit = build()..setFromFeeder(fromFeeder: true);
    final counts = <int>[];
    final watching = cubit.stream.listen((state) => counts.add(state.scanned));

    await cubit.copy();
    await watching.cancel();

    expect(backend.scansStarted.single, contains('Feeder'));
    expect(cubit.state.scanned, 3);
    // The count climbed as the sheets came in.
    expect(counts, containsAllInOrder([1, 2, 3]));
  });

  test('keeps the number of copies between one and the most allowed', () {
    final cubit = build()..setCopies(0);
    expect(cubit.state.copies, 1);

    cubit.setCopies(500);
    expect(cubit.state.copies, CopyCubit.maxCopies);
  });

  test('says why the scanner stopped, and prints nothing', () async {
    backend
      ..scannerRefuses = 409
      ..scannerFeeder = 'ScannerAdfEmpty';
    final cubit = build()..setFromFeeder(fromFeeder: true);

    await cubit.copy();

    expect(cubit.state.step, CopyStep.choosing);
    expect(cubit.state.failure, 'scan.feeder_empty');
    expect(backend.printed, isEmpty);
  });

  test('says why the printer stopped', () async {
    backend.printerRefuses = IppStatus.clientErrorNotPossible;
    final cubit = build();

    await cubit.copy();

    expect(cubit.state.step, CopyStep.choosing);
    expect(cubit.state.failure, isNotNull);
    expect(cubit.state.failure, isNot(startsWith('scan.')));
  });

  test('says what the backend said when it will not record the scan, or '
      'the print', () async {
    backend.fail(_jobs, 403, 'permission.denied');
    final cubit = build();

    await cubit.copy();

    expect(cubit.state.step, CopyStep.choosing);
    expect(cubit.state.error, isA<ApiException>());
    expect(cubit.state.failure, isNull);
    expect(backend.scansStarted, isEmpty);
  });

  test('says when the scan cannot be kept, or read to print', () async {
    final missing = Directory('${backend.scans.path}/missing');
    final unkept = build(directory: missing);
    await unkept.copy();
    expect(unkept.state.failure, 'scan.storage');

    backend.renderer.unreadable = true;
    final unread = build();
    await unread.copy();
    expect(unread.state.failure, 'copy.unreadable');
    expect(backend.printed, isEmpty);
  });

  test('stops at the scanner, and prints nothing of what came', () async {
    backend.scanPages = [tinyJpeg, tinyJpeg, tinyJpeg];
    final cubit = build()..setFromFeeder(fromFeeder: true);

    final copying = cubit.copy();
    await cubit.stream.firstWhere((state) => state.scanned >= 1);
    await cubit.cancel();
    await copying;

    expect(cubit.state.step, CopyStep.choosing);
    expect(cubit.state.failure, isNull);
    expect(backend.printed, isEmpty);
  });

  test('stops at the printer', () async {
    // The printer holds the job as still printing until it is cancelled.
    backend.printerJobState = 5;
    final cubit = build();

    final copying = cubit.copy();
    await cubit.stream.firstWhere(
      (state) => state.progress?.stage == PrintStage.printing,
    );
    await cubit.cancel();
    await copying;

    expect(cubit.state.step, CopyStep.choosing);
    expect(cubit.state.failure, isNull);
  });

  test('changes nothing, and stops nothing, while there is nothing to '
      'stop or it is at work', () async {
    final cubit = build();
    await cubit.cancel();
    cubit.again();
    expect(cubit.state, const CopyState());

    final copying = cubit.copy();
    cubit
      ..setCopies(9)
      ..setColor(color: false)
      ..setFromFeeder(fromFeeder: true);
    await cubit.copy();
    await copying;

    expect(cubit.state.copies, 1);
    expect(backend.scansStarted, hasLength(1));
  });

  test('goes back to make another copy', () async {
    final cubit = build();
    await cubit.copy();

    cubit.again();
    expect(cubit.state.step, CopyStep.choosing);

    await cubit.copy();
    expect(cubit.state.step, CopyStep.done);
    expect(backend.printed, hasLength(2));
    // Only the new page, not the one from before.
    expect(cubit.state.scanned, 1);
  });

  test('says nothing once the screen has gone', () async {
    for (final at in [
      (CopyState state) => state.step == CopyStep.scanning,
      (CopyState state) => state.step == CopyStep.printing,
    ]) {
      final cubit = build();
      final copying = cubit.copy();
      if (!at(cubit.state)) await cubit.stream.firstWhere(at);
      await cubit.close();
      await copying;
    }
  });
}
