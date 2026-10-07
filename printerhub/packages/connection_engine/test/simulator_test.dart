// Probes `backend/simulator`. Start it with `make simulator`, then:
//
//   dart test --tags simulator
@Tags(['simulator'])
library;

import 'dart:io';

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
}
