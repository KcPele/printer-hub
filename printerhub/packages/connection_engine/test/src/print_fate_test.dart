import 'package:connection_engine/connection_engine.dart';
import 'package:printer_protocols/printer_protocols.dart';
import 'package:printer_protocols/testing.dart';
import 'package:test/test.dart';

/// A printer that only answers questions about its jobs.
class _Printer {
  /// The jobs it has, by its own number: their name and state.
  Map<int, ({String name, int state, List<String> reasons})> jobs = {};

  /// The status it answers a question about one job with, when not OK.
  int? refuses;
  final List<int> operations = [];

  IppGroup _job(int id) => IppGroup(IppGroupTag.job, [
    IppAttribute.single('job-id', IppValueTag.integer, id),
    IppAttribute.single('job-state', IppValueTag.enumeration, jobs[id]!.state),
    IppAttribute.single('job-name', IppValueTag.name, jobs[id]!.name),
    if (jobs[id]!.reasons.isNotEmpty)
      IppAttribute.all(
        'job-state-reasons',
        IppValueTag.keyword,
        jobs[id]!.reasons,
      ),
  ]);

  FakeAnswer answer(SentRequest request) {
    final decoded = decodeIpp(request.body);
    operations.add(decoded.message.code);
    FakeAnswer ipp({
      int status = IppStatus.ok,
      List<IppGroup> groups = const [],
    }) {
      return FakeAnswer.ipp(ippResponse(status: status, groups: groups));
    }

    if (decoded.message.code == IppOperation.getJobAttributes) {
      if (refuses != null) return ipp(status: refuses!);
      final id =
          decoded.message.group(IppGroupTag.operation)!['job-id']!.first!
              as int;
      return jobs.containsKey(id)
          ? ipp(groups: [_job(id)])
          : ipp(status: IppStatus.clientErrorNotFound);
    }
    final finished =
        decoded.message.group(IppGroupTag.operation)!['which-jobs']!.first ==
        'completed';
    return ipp(
      groups: [
        for (final MapEntry(key: id, value: job) in jobs.entries)
          if ((job.state >= 7) == finished) _job(id),
      ],
    );
  }
}

final _ipp = DeviceConnection(
  type: 'ipp',
  uri: Uri.parse('ipp://192.168.1.40:631/ipp/print'),
);
final _ipps = DeviceConnection(
  type: 'ipps',
  uri: Uri.parse('ipps://192.168.1.40:443/ipp/print'),
);
final _escl = DeviceConnection(
  type: 'escl',
  uri: Uri.parse('http://192.168.1.40/eSCL'),
);

void main() {
  late _Printer printer;
  late FakePrinterHttp http;
  late PrintRunner runner;
  final name = PrintRunner.jobNameFor('Report.pdf', 'ab12cd34');

  setUp(() {
    printer = _Printer();
    http = FakePrinterHttp(printer.answer);
    runner = PrintRunner(http: http);
  });

  Future<PrintProgress?> fate({
    int? printerJobId,
    List<DeviceConnection>? connections,
  }) {
    return runner.fate(
      connections: connections ?? [_escl, _ipp],
      jobName: name,
      printerJobId: printerJobId,
    );
  }

  void has(int state, {List<String> reasons = const [], int id = 7}) {
    printer.jobs[id] = (name: name, state: state, reasons: reasons);
  }

  test('a print is named for its document and its own reference', () {
    expect(name, 'Report.pdf [ab12cd34]');
  });

  group('a job the printer still has, asked for by its number', () {
    test('that finished is done', () async {
      has(9);

      final answer = await fate(printerJobId: 7);

      expect(answer!.stage, PrintStage.completed);
      expect(answer.printerJobId, 7);
      expect(answer.connection, _ipp);
      expect(answer.errorCode, isNull);
      expect(answer.isFinal, isTrue);
    });

    test('that was cancelled at the printer is cancelled', () async {
      has(7, reasons: ['job-canceled-at-device']);

      final answer = await fate(printerJobId: 7);

      expect(answer!.stage, PrintStage.cancelled);
      expect(answer.reasons, ['job-canceled-at-device']);
    });

    test('that the printer gave up on failed, and says why', () async {
      has(8, reasons: ['document-format-error']);

      final answer = await fate(printerJobId: 7);

      expect(answer!.stage, PrintStage.failed);
      expect(answer.errorCode, 'ipp.job-aborted');
      expect(answer.errorMessage, 'document-format-error');
    });

    test('that is still going is still printing', () async {
      has(5);

      final answer = await fate(printerJobId: 7);

      expect(answer!.stage, PrintStage.printing);
      expect(answer.isFinal, isFalse);
    });

    test('that is waiting for something wants attention', () async {
      has(6, reasons: ['media-empty-error']);

      final answer = await fate(printerJobId: 7);

      expect(answer!.stage, PrintStage.attention);
      expect(answer.reasons, ['media-empty-error']);
    });
  });

  test(
    'a job whose number the printer has lost is found by its name',
    () async {
      has(9, id: 12);

      final answer = await fate(printerJobId: 7);

      expect(answer!.stage, PrintStage.completed);
      expect(answer.printerJobId, 12);
    },
  );

  test('a job the printer once had and no longer knows is unknown, not '
      'done', () async {
    final answer = await fate(printerJobId: 7);

    expect(answer!.stage, PrintStage.unknown);
    expect(answer.errorCode, 'print.outcome_unknown');
    expect(answer.printerJobId, 7);
  });

  group('a job the app never learned the number of', () {
    test('is found by its name when the document did arrive', () async {
      has(5);

      final answer = await fate();

      expect(answer!.stage, PrintStage.printing);
      expect(answer.printerJobId, 7);
      // Asked among the running and the finished, and nothing else.
      expect(printer.operations, [IppOperation.getJobs, IppOperation.getJobs]);
    });

    test('is found among the finished too', () async {
      has(9);

      expect((await fate())!.stage, PrintStage.completed);
    });

    test('never reached a printer that has nothing by its name', () async {
      printer.jobs[3] = (name: 'Other.pdf [zz99]', state: 9, reasons: []);

      final answer = await fate();

      expect(answer!.stage, PrintStage.failed);
      expect(answer.errorCode, 'print.interrupted');
      expect(answer.printerJobId, isNull);
    });
  });

  group('a printer that cannot be asked', () {
    test('is asked another way when one does not answer', () async {
      has(9);
      http.device = (request) => request.uri.scheme == 'http'
          ? throw PrinterUnreachable(request.uri, 'nothing there')
          : printer.answer(request);

      final answer = await fate(printerJobId: 7, connections: [_ipp, _ipps]);

      expect(answer!.stage, PrintStage.completed);
      expect(answer.connection, _ipps);
    });

    test('gives no answer when nothing answers', () async {
      http.device = (request) =>
          throw PrinterUnreachable(request.uri, 'nothing there');

      expect(await fate(printerJobId: 7, connections: [_ipp, _ipps]), isNull);
    });

    test('gives no answer when it will not say', () async {
      has(9);
      printer.refuses = IppStatus.serverErrorServiceUnavailable;

      expect(await fate(printerJobId: 7), isNull);
    });

    test(
      'gives no answer when the printer has no way to print saved',
      () async {
        expect(await fate(connections: [_escl]), isNull);
        expect(http.requests, isEmpty);
      },
    );
  });

  test('nothing is ever sent to print', () async {
    has(5);
    await fate(printerJobId: 7);
    await fate();
    await fate(printerJobId: 99);

    expect(printer.operations, isNot(contains(IppOperation.printJob)));
    expect(printer.operations, isNot(contains(IppOperation.validateJob)));
  });
}
