// The whole path with nothing faked: the local backend (`make dev`) and the
// printer simulator (`make simulator`).
//
//   flutter test --tags live
//
// Skipped when either is not running. It registers a throwaway account on
// the backend and deletes it at the end.
@Tags(['live'])
library;

import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_store/local_store.dart';
import 'package:printer_protocols/printer_protocols.dart';
import 'package:printers_repository/printers_repository.dart';

const _api = 'http://localhost:8000';
const _simulator = 'localhost:8631';

Future<bool> _listening(int port) async {
  try {
    final socket = await Socket.connect(
      'localhost',
      port,
      timeout: const Duration(seconds: 1),
    );
    socket.destroy();
    return true;
  } on Object {
    return false;
  }
}

void main() {
  test(
    'adds the simulated printer to a workspace and reads its status',
    () async {
      if (!await _listening(8000) || !await _listening(8631)) {
        markTestSkipped('Needs `make dev` and `make simulator`.');
        return;
      }
      // Widget tests block real network calls. This test is about them.
      HttpOverrides.global = null;

      final client = PrinterHubClient(
        baseUrl: Uri.parse(_api),
        tokenStore: InMemoryTokenStore(),
      );
      final http = IoPrinterHttp();
      final repository = PrintersRepository(
        client: client,
        probe: DeviceProbe(http: http),
        runner: PrintRunner(http: http),
        scanner: ScanRunner(http: http),
        store: InMemorySecureStore(),
      );
      final password = 'live-${newIdempotencyKey()}';
      final registered = await client.api.auth.register(
        body: RegisterRequest(
          name: 'Live Test',
          email: 'live-${DateTime.now().microsecondsSinceEpoch}@example.com',
          password: password,
        ),
      );
      await client.startSession(registered.tokens);
      addTearDown(() async {
        await client.api.account.deleteAccount(
          body: AccountDeleteRequest(password: password),
        );
        http.close();
        await client.close();
      });
      final workspace = await client.api.organizations.createOrganization(
        body: const OrganizationCreate(name: 'Live workspace'),
      );

      final device = await repository.probe(_simulator);
      final added = await repository.add(
        organizationId: workspace.id,
        device: device,
        name: 'Simulated C7130',
        location: 'Test bench',
      );

      expect(added.friendlyName, 'Simulated C7130');
      expect(added.location, 'Test bench');
      expect(added.manufacturer, 'Xerox');
      expect(added.model, 'VersaLink C7130');
      expect(added.capabilities!.print.color, isTrue);
      expect(added.capabilities!.scan.supported, isTrue);
      expect(added.capabilities!.copy.supported, isTrue);
      expect(added.connections.map((c) => c.type.json), ['ipp', 'escl']);
      expect(added.status, PrinterStatus.online);
      expect(added.statusDetail.consumables, isNotEmpty);

      final listed = await repository.list(workspace.id);
      expect(listed.map((printer) => printer.id), [added.id]);

      final refreshed = await repository.refreshStatus(
        organizationId: workspace.id,
        printer: added,
      );
      expect(refreshed.status.state, 'online');
      expect(refreshed.printer.status, PrinterStatus.online);
      expect(refreshed.printer.lastSeenAt, isNotNull);

      final renamed = await repository.rename(
        organizationId: workspace.id,
        printerId: added.id,
        name: 'Front desk',
      );
      expect(renamed.friendlyName, 'Front desk');

      await repository.remove(
        organizationId: workspace.id,
        printerId: added.id,
      );
      expect(await repository.list(workspace.id), isEmpty);
    },
  );
}
