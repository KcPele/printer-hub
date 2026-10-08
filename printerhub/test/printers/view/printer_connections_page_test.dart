import 'package:api_client/testing.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printer_protocols/printer_protocols.dart';
import 'package:printer_protocols/testing.dart';
import 'package:printerhub/printers/printers.dart';

import '../../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';

void main() {
  late TestBackend backend;
  late PrintersCubit printers;

  setUp(() async {
    backend = TestBackend()
      ..printerList = [
        printerBody(
          connections: [
            {...connectionBody(), 'health': 'connected'},
            {
              ...connectionBody(
                type: 'escl',
                port: 80,
                path: '/eSCL',
                priority: 2,
              ),
              'health': 'config_required',
            },
          ],
        ),
      ];
    await backend.signedInBefore();
    printers = PrintersCubit(
      printersRepository: backend.printers,
      organizationId: _org,
      organizationChanges: const Stream.empty(),
    );
  });
  tearDown(() async {
    await printers.close();
    await backend.close();
  });

  Future<void> pump(WidgetTester tester, {bool offline = false}) async {
    // Only the list is read: checking the printers would report their
    // health afresh.
    final listed = await tester.runAsync(() => backend.printers.list(_org));
    printers.emit(
      PrintersState(status: PrintersStatus.ready, printers: listed!),
    );
    backend.offline = offline;
    await tester.pumpApp(
      const PrinterConnectionsPage(printerId: 'printer-1'),
      backend: backend,
      printersCubit: printers,
    );
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, int row, String action) async {
    await tester.tap(find.byTooltip('Show menu').at(row));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  List<Map<String, Object?>> saved() =>
      (backend.printerList.single['connections']! as List<dynamic>).cast();

  group('PrinterConnectionsPage', () {
    testWidgets('lists each way in, what it is for, and how it is doing', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Printing · 192.168.1.40'), findsOneWidget);
      expect(find.text('IPP · 631 · Tried first'), findsOneWidget);
      expect(find.text('Working'), findsOneWidget);
      expect(find.text('Scanning · 192.168.1.40'), findsOneWidget);
      expect(find.text('ESCL · 80'), findsOneWidget);
      expect(find.text('Not set up at this address'), findsOneWidget);
    });

    testWidgets('words every state a connection can be in', (tester) async {
      backend.printerList = [
        printerBody(
          connections: [
            for (final (index, health) in [
              'degraded',
              'unavailable',
              'auth_required',
              'unknown',
            ].indexed)
              {
                ...connectionBody(type: 'ipps', priority: index + 1),
                'id': 'c$index',
                'health': health,
              },
          ],
        ),
      ];

      await pump(tester);

      expect(find.text('Busy or stopped'), findsOneWidget);
      expect(find.text('Not answering'), findsOneWidget);
      expect(find.text('Wants a password'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Not tried yet'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Not tried yet'), findsOneWidget);
      expect(find.textContaining('Secure'), findsWidgets);
    });

    testWidgets('makes a connection the one tried first', (tester) async {
      await pump(tester);

      await choose(tester, 1, 'Try this first');

      expect(saved().map((c) => c['type']), ['escl', 'ipp']);
      expect(find.text('ESCL · 80 · Tried first'), findsOneWidget);
    });

    testWidgets('offers only what makes sense for a connection', (
      tester,
    ) async {
      await pump(tester);

      // The first is already first.
      await tester.tap(find.byTooltip('Show menu').first);
      await tester.pumpAndSettle();
      expect(find.text('Try this first'), findsNothing);
      expect(find.text('Change password'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      // A scanner is not asked for a password.
      await tester.tap(find.byTooltip('Show menu').last);
      await tester.pumpAndSettle();
      expect(find.text('Change password'), findsNothing);
    });

    testWidgets('removes a connection, but never the last', (tester) async {
      await pump(tester);

      await choose(tester, 1, 'Remove');

      expect(saved().map((c) => c['type']), ['ipp']);
      expect(find.text('Scanning · 192.168.1.40'), findsNothing);

      await tester.tap(find.byTooltip('Show menu'));
      await tester.pumpAndSettle();
      expect(find.text('Remove'), findsNothing);
    });

    testWidgets('replaces the printer’s password', (tester) async {
      await pump(tester);

      await choose(tester, 0, 'Change password');
      expect(find.text("The printer's user name and password"), findsOneWidget);

      // Both are needed.
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter the user name the printer asks for.'),
        findsOneWidget,
      );

      await tester.fill('User name', ' ada ');
      await tester.fill('Password', 'new pw');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(backend.printerPasswords['printer-1'], {
        'username': 'ada',
        'password': 'new pw',
      });
      expect(find.text('The password was changed.'), findsOneWidget);
    });

    testWidgets('leaves the password alone when cancelled', (tester) async {
      await pump(tester);

      await choose(tester, 0, 'Change password');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(backend.printerPasswords, isEmpty);
    });

    group('another address', () {
      Future<void> findAt(WidgetTester tester, String address) async {
        await tester.scrollUntilVisible(
          find.text('Find at this address'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(find.byType(TextField), address);
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
      }

      testWidgets('is added when the printer answers there', (tester) async {
        backend.plugInPrinter();
        await pump(tester);

        await findAt(tester, '192.168.1.77');

        expect(find.text('The new address was added.'), findsOneWidget);
        expect(saved(), hasLength(4));
      });

      testWidgets('is not added twice', (tester) async {
        backend.plugInPrinter();
        await pump(tester);

        await findAt(tester, '192.168.1.40');

        expect(
          find.text('The printer is already saved at that address.'),
          findsOneWidget,
        );
        expect(saved(), hasLength(2));
      });

      for (final (address, answer, message) in [
        ('two words', null, 'does not look like an address'),
        ('10.9.9.9', null, 'Nothing answered'),
        ('10.9.9.1', FakeAnswerKind.notFound, 'not a printer'),
        ('10.9.9.2', FakeAnswerKind.locked, 'Set them with Change password'),
      ]) {
        testWidgets('says why "$address" could not be added', (tester) async {
          backend.device.device = switch (answer) {
            FakeAnswerKind.notFound => (_) => const FakeAnswer(404),
            FakeAnswerKind.locked => (_) => const FakeAnswer(
              401,
              headers: {'www-authenticate': 'Digest realm="x", nonce="n"'},
            ),
            null => backend.device.device,
          };
          await pump(tester);

          await findAt(tester, address);

          await tester.scrollUntilVisible(
            find.byType(AppNotice),
            -200,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.textContaining(message), findsOneWidget);
          expect(saved(), hasLength(2));
        });
      }

      testWidgets('says when the printer refuses the kept password', (
        tester,
      ) async {
        backend.printerList = [
          printerBody(connections: [connectionBody(hasCredentials: true)]),
        ];
        backend.printerPasswords['printer-1'] = {
          'username': 'ada',
          'password': 'old',
        };
        backend.plugInPrinter(
          signIn: const PrinterCredentials(userName: 'ada', password: 'new'),
        );
        await pump(tester);

        await findAt(tester, '192.168.1.77');

        expect(find.textContaining('did not accept'), findsOneWidget);
      });
    });

    testWidgets('says why a change was refused', (tester) async {
      await pump(tester);
      backend.offline = true;

      await choose(tester, 1, 'Remove');

      expect(find.textContaining("Can't reach PrinterHub"), findsOneWidget);
      expect(find.text('Scanning · 192.168.1.40'), findsOneWidget);
    });

    testWidgets('says when the list cannot be read, and tries again', (
      tester,
    ) async {
      await pump(tester, offline: true);

      expect(find.text("Couldn't load the connections"), findsOneWidget);

      backend.offline = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Printing · 192.168.1.40'), findsOneWidget);
    });
  });
}

enum FakeAnswerKind { notFound, locked }
