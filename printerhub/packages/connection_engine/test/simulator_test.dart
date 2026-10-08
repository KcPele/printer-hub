// Probes `backend/simulator`. Start it with `make simulator`, then:
//
//   dart test --tags simulator
@Tags(['simulator'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:connection_engine/connection_engine.dart';
import 'package:printer_protocols/printer_protocols.dart';
import 'package:test/test.dart';

final Uri _base = Uri.parse(
  Platform.environment['SIMULATOR_URL'] ?? 'http://localhost:8631',
);

Future<bool> _running() async {
  try {
    final socket = await Socket.connect(
      _base.host,
      _base.port,
      timeout: const Duration(seconds: 1),
    );
    socket.destroy();
    return true;
  } on Object {
    return false;
  }
}

void main() {
  // Asked once, by the first test that needs it. Declaring tests must not
  // wait on anything, so each test checks and skips itself.
  final up = _running();
  final http = IoPrinterHttp();
  final probe = DeviceProbe(http: http);
  tearDownAll(http.close);

  test('describes the simulated C7130 from its address alone', () async {
    if (!await up) {
      markTestSkipped('The simulator is not running (make simulator).');
      return;
    }
    final device = await probe.probe('${_base.host}:${_base.port}');

    expect(device.manufacturer, 'Xerox');
    expect(device.model, 'VersaLink C7130');
    expect(device.connections.map((c) => c.type), ['ipp', 'escl']);
    expect(device.print!.color, isTrue);
    expect(device.print!.duplex, isTrue);
    expect(device.print!.trays, isNotEmpty);
    expect(device.scan!.hasGlass, isTrue);
    expect(device.scan!.hasFeeder, isTrue);
    expect(device.status.state, 'online');
    expect(device.status.supplies.map((s) => s.color), contains('cyan'));

    final status = await probe.status(device.connections);
    expect(status.state, 'online');
    expect(status.scannerState, 'idle');
  });

  group('printing', () {
    final control = HttpClient();
    tearDownAll(() => control.close(force: true));

    Future<Map<String, dynamic>> simulator(
      String method,
      String path, [
      Map<String, Object?>? body,
    ]) async {
      final request = await control.openUrl(method, _base.replace(path: path));
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final answer = await utf8.decodeStream(await request.close());
      return jsonDecode(answer) as Map<String, dynamic>;
    }

    final printing = DeviceConnection(
      type: 'ipp',
      uri: Uri(
        scheme: 'ipp',
        host: _base.host,
        port: _base.port,
        path: '/ipp/print',
      ),
    );
    // Nothing listens here: a connection that has gone quiet.
    final dead = DeviceConnection(
      type: 'ipp',
      uri: Uri(scheme: 'ipp', host: _base.host, port: 9, path: '/ipp/print'),
    );
    final pdf = utf8.encode('%PDF-1.7 from the print runner');

    PrintDocument document() => PrintDocument(
      name: 'Runner.pdf',
      mimeType: 'application/pdf',
      length: pdf.length,
      open: () => Stream.value(pdf),
      pageCount: 2,
      rasterise: (page) async* {
        for (var i = 0; i < 2; i++) {
          yield Uint8List(page.bytesPerPage)
            ..fillRange(0, page.bytesPerPage, 255)
            ..fillRange(0, page.bytesPerLine * 50, 30);
        }
      },
    );

    Future<List<PrintProgress>> print(
      List<DeviceConnection> connections, {
      PrintRequest request = const PrintRequest(),
    }) {
      return PrintRunner(
            http: IoPrinterHttp(connectTimeout: const Duration(seconds: 1)),
            pollInterval: const Duration(milliseconds: 100),
          )
          .start(
            connections: connections,
            document: document(),
            request: request,
            reference: 'sim-${DateTime.now().microsecondsSinceEpoch}',
          )
          .progress
          .toList();
    }

    Future<List<dynamic>> jobs() async =>
        (await simulator('GET', '/sim/state'))['print_jobs'] as List<dynamic>;

    setUp(() async {
      if (await up) {
        await simulator('POST', '/sim/reset');
        await simulator('PATCH', '/sim/state', {'job_duration_seconds': 0.3});
      }
    });

    test('prints a PDF and follows it to the end', () async {
      if (!await up) return markTestSkipped('The simulator is not running.');

      final steps = await print([
        printing,
      ], request: const PrintRequest(copies: 2, sides: 'two_sided_long_edge'));

      expect(steps.last.stage, PrintStage.completed);
      final printed = (await jobs()).single as Map;
      expect(printed['document_format'], 'application/pdf');
      expect(printed['size_bytes'], pdf.length);
      expect(printed['name'], startsWith('Runner.pdf [sim-'));
    });

    test('draws the pages for a printer that does not read PDF', () async {
      if (!await up) return markTestSkipped('The simulator is not running.');
      await simulator('PATCH', '/sim/state', {
        'document_formats': ['image/urf'],
      });

      final steps = await print([printing]);

      expect(steps.last.stage, PrintStage.completed);
      final printed = (await jobs()).single as Map;
      expect(printed['document_format'], 'image/urf');
      // The simulator read the pages back the way a printer would.
      expect(printed['pages'], 2);
    });

    test('moves to the next connection, and prints once', () async {
      if (!await up) return markTestSkipped('The simulator is not running.');

      final steps = await print([dead, printing]);

      expect(steps.last.stage, PrintStage.completed);
      expect(steps.last.fellBack, isTrue);
      expect(steps.last.connection, printing);
      expect(await jobs(), hasLength(1));
    });

    test('says what the printer wants when it stops', () async {
      if (!await up) return markTestSkipped('The simulator is not running.');
      await simulator('PATCH', '/sim/state', {
        'faults': {'paper_jam': true},
      });

      final run =
          PrintRunner(
            http: IoPrinterHttp(),
            pollInterval: const Duration(milliseconds: 100),
          ).start(
            connections: [printing],
            document: document(),
            request: const PrintRequest(),
            reference: 'jam',
          );
      final stages = <PrintStage>[];
      await for (final step in run.progress) {
        stages.add(step.stage);
        if (step.stage == PrintStage.attention) {
          // Someone clears the jam.
          await simulator('PATCH', '/sim/state', {
            'faults': {'paper_jam': false},
          });
        }
      }

      expect(
        stages,
        containsAllInOrder([
          PrintStage.printing,
          PrintStage.attention,
          PrintStage.completed,
        ]),
      );
    });

    test('cancels a job on the printer', () async {
      if (!await up) return markTestSkipped('The simulator is not running.');
      await simulator('PATCH', '/sim/state', {'job_duration_seconds': 30});

      final run =
          PrintRunner(
            http: IoPrinterHttp(),
            pollInterval: const Duration(milliseconds: 100),
          ).start(
            connections: [printing],
            document: document(),
            request: const PrintRequest(),
            reference: 'cancel',
          );
      PrintProgress? last;
      await for (final step in run.progress) {
        last = step;
        if (step.stage == PrintStage.printing) await run.cancel();
      }

      expect(last!.stage, PrintStage.cancelled);
    });

    test('fails when the printer is offline everywhere', () async {
      if (!await up) return markTestSkipped('The simulator is not running.');
      await simulator('PATCH', '/sim/state', {
        'faults': {'offline': true},
      });

      final steps = await print([printing]);

      expect(steps.last.stage, PrintStage.failed);
      expect(steps.last.errorCode, 'ipp.server-error-service-unavailable');
      expect(await jobs(), isEmpty);
    });
  });
}
