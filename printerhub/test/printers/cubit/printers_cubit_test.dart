import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/auth/auth.dart';
import 'package:printerhub/printers/printers.dart';
import 'package:printers_repository/printers_repository.dart';

import '../../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';

void main() {
  late TestBackend backend;
  late StreamController<String?> organizations;

  setUp(() {
    backend = TestBackend()
      ..printerList = [
        printerBody(),
        printerBody(id: 'printer-2', name: 'Lobby'),
      ];
    organizations = StreamController<String?>();
  });
  tearDown(() async {
    await organizations.close();
    await backend.close();
  });

  PrintersCubit build({String? organizationId = _org}) {
    final cubit = PrintersCubit(
      printersRepository: backend.printers,
      organizationId: organizationId,
      organizationChanges: organizations.stream,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  PrinterRead first(PrintersCubit cubit) => cubit.state.printers.first;

  group('load', () {
    test('lists the printers, then asks each what it is doing', () async {
      backend.plugInPrinter();
      final cubit = build();
      final statuses = <PrintersStatus>[];
      final subscription = cubit.stream.listen((s) => statuses.add(s.status));
      addTearDown(subscription.cancel);

      await cubit.load();

      expect(statuses.first, PrintersStatus.loading);
      expect(cubit.state.status, PrintersStatus.ready);
      expect(cubit.state.printers.map((p) => p.friendlyName), [
        'Front desk',
        'Lobby',
      ]);
      expect(cubit.state.live.keys, ['printer-1', 'printer-2']);
      expect(cubit.state.live['printer-1']!.state, 'online');
      expect(cubit.state.checking, isEmpty);
      expect(cubit.state.printer('printer-2')!.friendlyName, 'Lobby');
      expect(cubit.state.printer('nope'), isNull);
    });

    test('marks printers that do not answer as unreachable', () async {
      final cubit = build();

      await cubit.load();

      expect(cubit.state.live['printer-1'], DeviceStatus.unreachable);
      expect(first(cubit).status, PrinterStatus.unreachable);
    });

    test('does nothing without a workspace', () async {
      final cubit = build(organizationId: null);

      await cubit.load();
      await cubit.checkStatus(PrinterRead.fromJson(printerBody().cast()));

      expect(cubit.state, const PrintersState());
      expect(backend.network.requests, isEmpty);
    });

    test('says why the list could not be loaded', () async {
      backend.fail('GET /organizations/$_org/printers', 500, 'internal_error');
      final cubit = build();

      await cubit.load();

      expect(cubit.state.status, PrintersStatus.failure);
      expect(cubit.state.error, isA<ApiProblem>());
      expect(cubit.state.printers, isEmpty);
    });

    test('keeps the printers on screen when a reload fails', () async {
      final cubit = build();
      await cubit.load();
      backend.offline = true;
      await backend.printers.clear([_org]);

      await cubit.load();

      expect(cubit.state.status, PrintersStatus.failure);
      expect(cubit.state.printers, hasLength(2));
    });
  });

  group('the workspace', () {
    test('loading follows a change of workspace', () async {
      backend.printerList = [
        printerBody(),
        printerBody(id: 'other', name: 'Annex', organizationId: 'org-2'),
      ];
      final cubit = build();
      await cubit.load();
      expect(first(cubit).friendlyName, 'Front desk');

      organizations.add('org-2');
      await pumpEventQueue();

      expect(cubit.state.printers.single.friendlyName, 'Annex');
      expect(cubit.state.live.keys, ['other']);
    });

    test('nothing reloads when the workspace stays the same', () async {
      final cubit = build();
      await cubit.load();
      backend.network.requests.clear();

      organizations.add(_org);
      await pumpEventQueue();

      expect(backend.network.requests, isEmpty);
    });

    test('signing out empties the list', () async {
      final cubit = build();
      await cubit.load();

      organizations.add(null);
      await pumpEventQueue();

      expect(cubit.state, const PrintersState());
    });

    test('an answer for the old workspace is dropped', () async {
      final gate = Completer<void>();
      backend.routes['GET /organizations/$_org/printers'] = (_) async {
        await gate.future;
        return FakeResponse(200, {
          'items': [printerBody()],
          'next_cursor': null,
        });
      };
      final cubit = build();

      final loading = cubit.load();
      organizations.add('org-2');
      await pumpEventQueue();
      gate.complete();
      await loading;

      expect(cubit.state.printers, isEmpty);
    });

    test('a failure for the old workspace is dropped', () async {
      final gate = Completer<void>();
      backend.routes['GET /organizations/$_org/printers'] = (_) async {
        await gate.future;
        return FakeResponse.problem(500, 'internal_error');
      };
      final cubit = build();

      final loading = cubit.load();
      organizations.add('org-2');
      await pumpEventQueue();
      gate.complete();
      await loading;

      expect(cubit.state.status, PrintersStatus.ready);
    });

    test('a status for the old workspace is dropped', () async {
      final cubit = build();
      await cubit.load();
      final printer = first(cubit);
      final gate = Completer<void>();
      backend.routes['POST /organizations/$_org/printers/printer-1/status'] =
          (_) async {
            await gate.future;
            return FakeResponse(200, printerBody());
          };

      final checking = cubit.checkStatus(printer);
      await pumpEventQueue();
      organizations.add('org-2');
      await pumpEventQueue();
      gate.complete();
      await checking;

      expect(cubit.state.live, isEmpty);
    });
  });

  group('checkStatus', () {
    test('updates one printer from the device itself', () async {
      final cubit = build();
      await cubit.load();
      backend.plugInPrinter(stateReasons: ['media-jam-error']);

      await cubit.checkStatus(first(cubit));

      final live = cubit.state.live['printer-1']!;
      expect(live.state, 'online');
      expect(live.alerts.single.code, 'media-jam');
      expect(first(cubit).status, PrinterStatus.online);
      expect(cubit.state.live['printer-2'], DeviceStatus.unreachable);
    });

    test('does not ask a printer twice at once', () async {
      final cubit = build();
      await cubit.load();
      backend.device.requests.clear();
      backend.plugInPrinter();

      await Future.wait([
        cubit.checkStatus(first(cubit)),
        cubit.checkStatus(first(cubit)),
      ]);

      expect(
        backend.device.requests.where((r) => r.uri.path.contains('ipp')),
        hasLength(1),
      );
    });
  });

  test('added puts a new printer in the list without a reload', () async {
    final cubit = build();
    final printer = PrinterRead.fromJson(printerBody(id: 'new').cast());

    cubit.added(printer, const DeviceStatus(state: 'online'));

    expect(cubit.state.status, PrintersStatus.ready);
    expect(cubit.state.printers.single.id, 'new');
    expect(cubit.state.live['new']!.state, 'online');
    expect(backend.network.requests, isEmpty);
  });

  group('remove', () {
    test('removes the printer from the workspace and the list', () async {
      final cubit = build();
      await cubit.load();

      await cubit.remove('printer-1');

      expect(cubit.state.printers.single.id, 'printer-2');
      expect(cubit.state.live.containsKey('printer-1'), isFalse);
      expect(backend.printerList.single['id'], 'printer-2');
    });

    test('keeps the printer when the backend refuses', () async {
      final cubit = build();
      await cubit.load();
      backend.fail(
        'DELETE /organizations/$_org/printers/printer-1',
        403,
        'permission.denied',
      );

      await expectLater(cubit.remove('printer-1'), throwsA(isA<ApiProblem>()));
      expect(cubit.state.printers, hasLength(2));
    });

    test('RemovePrinterCubit reports the outcome', () async {
      final cubit = build();
      await cubit.load();
      final removal = RemovePrinterCubit(printersCubit: cubit);
      addTearDown(removal.close);

      await removal.submit(printerId: 'printer-1');

      expect(removal.state.status, SubmitStatus.success);
      expect(cubit.state.printers, hasLength(1));
    });
  });
}
