import 'dart:async';

import 'package:api_client/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printer_discovery/printer_discovery.dart';
import 'package:printer_protocols/printer_protocols.dart';
import 'package:printer_protocols/testing.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/printers/printers.dart';
import 'package:printerhub/session/session.dart';

import '../../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';

const _announced = NearbyDevice(
  name: 'Front desk printer',
  host: '192.168.1.40',
  model: 'Xerox VersaLink C7130',
);

void main() {
  group('AddPrinterPage', () {
    late TestBackend backend;
    late MockGoRouter router;
    late PrintersCubit printers;

    setUp(() async {
      backend = TestBackend();
      router = recordingRouter();
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

    // The list of ways shows a spinner while it looks for printers, which
    // never settles, so time is moved on by hand.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> pump(WidgetTester tester, {SessionCubit? session}) async {
      await tester.pumpApp(
        const AddPrinterPage(),
        backend: backend,
        printersCubit: printers,
        sessionCubit: session,
        router: router,
      );
      await settle(tester);
    }

    Future<void> open(WidgetTester tester, String way) async {
      await tester.ensureVisible(find.text(way));
      await tester.tap(find.text(way));
      await settle(tester);
    }

    Future<void> findAt(WidgetTester tester, String address) async {
      await open(tester, 'Enter an address');
      await tester.enterText(find.byType(TextField).first, address);
      await tester.tap(find.text('Find printer'));
      await settle(tester);
    }

    group('the ways to connect', () {
      testWidgets('are all offered, with the network being searched', (
        tester,
      ) async {
        await pump(tester);

        expect(find.text('Nearby printers'), findsOneWidget);
        expect(find.text('Looking on your Wi-Fi…'), findsOneWidget);
        for (final way in [
          'Enter an address',
          'Scan a code',
          'Tap the printer',
          'Wi-Fi Direct',
          'Find by Bluetooth',
        ]) {
          expect(find.text(way), findsOneWidget);
        }
      });

      testWidgets('say when the phone cannot use one', (tester) async {
        backend
          ..nfc.available = false
          ..bluetooth.available = false;
        await pump(tester);

        expect(find.text('NFC is off or not on this phone'), findsOneWidget);
        expect(
          find.text('Bluetooth is off or not on this phone'),
          findsOneWidget,
        );
        await open(tester, 'Find by Bluetooth');
        expect(find.text('Printers near you'), findsNothing);
      });

      testWidgets('stop looking when the screen is left', (tester) async {
        await pump(tester);
        expect(backend.nearby.listeners, 1);

        await tester.pumpWidget(const SizedBox());
        // The stand-in network lives outside the test's fake clock, so its
        // side of the goodbye needs real time to pass.
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
        await tester.runAsync(pumpEventQueue);

        expect(backend.nearby.listeners, 0);
      });
    });

    group('a printer on the same Wi-Fi', () {
      testWidgets('is listed as it is found, and added with a tap', (
        tester,
      ) async {
        backend.plugInPrinter();
        await pump(tester);

        backend.nearby.announce([
          NearbyDevice(
            name: _announced.name,
            host: _announced.host,
            model: _announced.model,
            ipp: Uri.parse('ipp://192.168.1.40:631/ipp/print'),
            escl: Uri.parse('http://192.168.1.40:80/eSCL'),
          ),
        ]);
        await settle(tester);
        expect(find.text('Xerox VersaLink C7130'), findsOneWidget);
        expect(find.textContaining('Prints · Scans'), findsOneWidget);
        expect(find.text('Looking on your Wi-Fi…'), findsNothing);

        await tester.tap(find.text('Xerox VersaLink C7130'));
        await tester.pumpAndSettle();

        expect(find.text('Found it'), findsOneWidget);
      });

      testWidgets('is listed by its name when it gives no model', (
        tester,
      ) async {
        await pump(tester);

        backend.nearby.announce(const [
          NearbyDevice(name: 'Lobby scanner', host: '10.0.0.9'),
        ]);
        await settle(tester);

        expect(find.text('Lobby scanner'), findsOneWidget);
        expect(find.textContaining('10.0.0.9'), findsOneWidget);
      });

      testWidgets('says when it has gone by the time it is tapped', (
        tester,
      ) async {
        await pump(tester);
        backend.nearby.announce(const [_announced]);
        await settle(tester);

        await tester.tap(find.text('Xerox VersaLink C7130'));
        await settle(tester);

        expect(find.textContaining('Nothing answered'), findsOneWidget);
      });
    });

    group('by address', () {
      testWidgets(
        'says when the address is not one, and keeps what was typed',
        (tester) async {
          await pump(tester);

          await findAt(tester, 'two words');

          expect(
            find.textContaining('does not look like an address'),
            findsOneWidget,
          );
          expect(find.text('two words'), findsOneWidget);
        },
      );

      testWidgets('says when nothing answers', (tester) async {
        await pump(tester);

        await findAt(tester, '10.0.0.99');

        expect(find.textContaining('Nothing answered'), findsOneWidget);
        expect(find.text('10.0.0.99'), findsOneWidget);
      });

      testWidgets('says when what answers is not a printer', (tester) async {
        backend.device.device = (_) => const FakeAnswer(404);
        await pump(tester);

        await findAt(tester, '10.0.0.1');

        expect(find.textContaining('not a printer'), findsOneWidget);
      });

      testWidgets('shows progress while the printer is being asked', (
        tester,
      ) async {
        final answer = Completer<void>();
        backend.device.device = (request) async {
          await answer.future;
          throw PrinterUnreachable(request.uri, 'gone');
        };
        await pump(tester);
        await open(tester, 'Enter an address');
        await tester.enterText(find.byType(TextField).first, '10.0.0.7:631');

        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();

        expect(find.textContaining('Asking the printer'), findsOneWidget);

        answer.complete();
        await settle(tester);
        expect(find.text('Find printer'), findsOneWidget);
      });

      testWidgets('goes back to the ways, then out', (tester) async {
        await pump(tester);
        await open(tester, 'Enter an address');
        expect(find.text('Find printer'), findsOneWidget);

        // The screen's own back handling, outermost of any inside it.
        PopScope<dynamic> backHandling() {
          return tester.widget<PopScope<dynamic>>(
            find
                .descendant(
                  of: find.byType(AddPrinterView),
                  matching: find.byWidgetPredicate(
                    (widget) => widget is PopScope,
                  ),
                )
                .first,
          );
        }

        expect(backHandling().canPop, isFalse);
        backHandling().onPopInvokedWithResult!(false, null);
        await settle(tester);

        expect(find.text('Nearby printers'), findsOneWidget);
        expect(backHandling().canPop, isTrue);
        backHandling().onPopInvokedWithResult!(true, null);
        await settle(tester);
        expect(find.text('Nearby printers'), findsOneWidget);
      });
    });

    group('once the printer is found', () {
      Future<void> found(WidgetTester tester) async {
        backend.plugInPrinter();
        await pump(tester);
        await findAt(tester, '10.0.0.7');
        await tester.pumpAndSettle();
      }

      testWidgets('says what it can do and suggests a name', (tester) async {
        await found(tester);

        expect(find.text('Found it'), findsOneWidget);
        expect(find.text('Prints in colour'), findsOneWidget);
        expect(find.text('Prints on both sides'), findsOneWidget);
        expect(
          find.text('Scans from the glass and the feeder'),
          findsOneWidget,
        );
        expect(find.text('Copies'), findsOneWidget);
        expect(
          find.widgetWithText(TextFormField, 'Xerox VersaLink C7130'),
          findsOneWidget,
        );
      });

      testWidgets('needs a name', (tester) async {
        await found(tester);
        await tester.fill('Name', '  ');

        await tester.ensureVisible(find.text('Add printer'));
        await tester.tap(find.text('Add printer'));
        await tester.pump();

        expect(find.text('Give the printer a name.'), findsOneWidget);
        expect(backend.printerList, isEmpty);
      });

      testWidgets('adds the printer and goes back to the list', (tester) async {
        await found(tester);
        await tester.fill('Name', 'Front desk');
        await tester.fill('Location (optional)', 'Second floor');

        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(backend.printerList.single['friendly_name'], 'Front desk');
        expect(backend.printerList.single['location'], 'Second floor');
        expect(printers.state.printers.single.friendlyName, 'Front desk');
        expect(printers.state.live['printer-1']!.state, 'online');
        expect(find.text('Front desk was added.'), findsOneWidget);
        verify(router.pop).called(1);
      });

      testWidgets('says why the printer could not be added', (tester) async {
        await found(tester);
        backend.offline = true;

        await tester.ensureVisible(find.text('Add printer'));
        await tester.tap(find.text('Add printer'));
        await tester.pumpAndSettle();

        expect(find.textContaining("Can't reach PrinterHub"), findsOneWidget);
        verifyNever(router.pop);
      });

      testWidgets('goes back to the ways to try another', (tester) async {
        await found(tester);

        await tester.ensureVisible(find.text('Try another address'));
        await tester.tap(find.text('Try another address'));
        await settle(tester);

        expect(find.text('Nearby printers'), findsOneWidget);
      });
    });

    group('a printer that asks who is printing', () {
      const ada = PrinterCredentials(userName: 'ada', password: 'pw');

      Future<void> asked(WidgetTester tester) async {
        backend.plugInPrinter(signIn: ada);
        await pump(tester);
        await findAt(tester, '10.0.0.7');
        await tester.pumpAndSettle();
      }

      Future<void> connect(WidgetTester tester) async {
        await tester.ensureVisible(find.text('Connect'));
        await tester.tap(find.text('Connect'));
        await tester.pumpAndSettle();
      }

      testWidgets('is asked for its user name and password', (tester) async {
        await asked(tester);

        expect(find.text('This printer asks who is printing'), findsOneWidget);
        expect(find.textContaining('saved encrypted'), findsOneWidget);
        expect(find.textContaining('did not accept'), findsNothing);
      });

      testWidgets('needs both before it tries', (tester) async {
        await asked(tester);
        final sent = backend.device.requests.length;

        await connect(tester);

        expect(
          find.text('Enter the user name the printer asks for.'),
          findsOneWidget,
        );
        expect(find.text("Enter the printer's password."), findsOneWidget);
        expect(backend.device.requests, hasLength(sent));
      });

      testWidgets('is found once signed in to, and saved with its password', (
        tester,
      ) async {
        await asked(tester);
        await tester.fill('User name', ' ada ');
        await tester.fill('Password', 'pw');

        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(find.text('Found it'), findsOneWidget);

        await tester.fill('Name', 'Locked printer');
        await tester.ensureVisible(find.text('Add printer'));
        await tester.tap(find.text('Add printer'));
        await tester.pumpAndSettle();

        expect(backend.printerPasswords['printer-1'], {
          'username': 'ada',
          'password': 'pw',
        });
      });

      testWidgets('says when the password is wrong', (tester) async {
        await asked(tester);
        await tester.fill('User name', 'ada');
        await tester.fill('Password', 'guess');

        await connect(tester);

        expect(find.textContaining('did not accept'), findsOneWidget);
        expect(find.text('Connect'), findsOneWidget);
      });

      testWidgets('says when the password cannot be sent safely', (
        tester,
      ) async {
        backend.device.device = (request) =>
            request.uri.scheme == 'http' && request.uri.port == 631
            ? const FakeAnswer(
                401,
                headers: {'www-authenticate': 'Basic realm="Printer"'},
              )
            : throw PrinterUnreachable(request.uri, 'nothing there');
        await pump(tester);
        await findAt(tester, '10.0.0.7');
        await tester.pumpAndSettle();
        await tester.fill('User name', 'ada');
        await tester.fill('Password', 'pw');

        await connect(tester);

        expect(find.textContaining('secure connection'), findsOneWidget);
      });

      testWidgets('goes back to the ways to connect', (tester) async {
        await asked(tester);

        final backHandling = tester.widget<PopScope<dynamic>>(
          find
              .descendant(
                of: find.byType(AddPrinterView),
                matching: find.byWidgetPredicate(
                  (widget) => widget is PopScope,
                ),
              )
              .first,
        );
        expect(backHandling.canPop, isFalse);
        backHandling.onPopInvokedWithResult!(false, null);
        await settle(tester);

        expect(find.text('Nearby printers'), findsOneWidget);
      });
    });

    group('by a code', () {
      testWidgets('shows the camera', (tester) async {
        await pump(tester);

        await open(tester, 'Scan a code');

        expect(find.byKey(TestBackend.qrCameraKey), findsOneWidget);
        expect(find.textContaining('Point the camera'), findsOneWidget);
      });

      testWidgets('finds a printer whose address is in the code', (
        tester,
      ) async {
        backend.plugInPrinter();
        await pump(tester);
        await open(tester, 'Scan a code');

        backend.scanCode('ipp://192.168.1.40:631/ipp/print');
        await tester.pumpAndSettle();

        expect(find.text('Found it'), findsOneWidget);
      });

      testWidgets('says when the code is not one it can use', (tester) async {
        await pump(tester);
        await open(tester, 'Scan a code');

        backend.scanCode('SN-0042-XYZ');
        await settle(tester);

        expect(
          find.textContaining('not a printer or a PrinterHub pairing code'),
          findsOneWidget,
        );
      });

      testWidgets('opens the printer a pairing code names', (tester) async {
        backend.printerList = [printerBody()];
        await pump(tester);
        await open(tester, 'Scan a code');

        backend.scanCode('printerhub://pair?token=token-printer-1');
        await settle(tester);

        expect(printers.state.printers.single.id, 'printer-1');
        expect(find.text('Opened Front desk.'), findsOneWidget);
        verify(() => router.go(AppRoutes.printer('printer-1'))).called(1);
      });

      testWidgets('switches to the workspace the paired printer is in', (
        tester,
      ) async {
        backend
          ..workspaces = [
            organizationBody(),
            organizationBody(id: 'org-2', name: 'Globex'),
          ]
          ..printerList = [printerBody(organizationId: 'org-2')];
        await tester.runAsync(backend.organizations.list);
        final session = SessionCubit(
          authRepository: backend.auth,
          organizationsRepository: backend.organizations,
          preferencesRepository: emptyPreferences(),
          keptOrganizations: await backend.organizations.kept(),
        );
        addTearDown(session.close);
        await pump(tester, session: session);
        await open(tester, 'Scan a code');

        backend.scanCode('printerhub://pair?token=token-printer-1');
        await settle(tester);

        expect(session.state.organization?.name, 'Globex');
        verify(() => router.go(AppRoutes.printer('printer-1'))).called(1);
      });

      testWidgets('says when a pairing code has expired', (tester) async {
        await pump(tester);
        await open(tester, 'Scan a code');

        backend.scanCode('printerhub://pair?token=expired');
        await settle(tester);

        expect(find.textContaining('not valid or has expired'), findsOneWidget);
        verifyNever(() => router.go(any()));
      });
    });

    group('by tapping the printer', () {
      testWidgets('waits for the tag, then finds the printer', (tester) async {
        backend.plugInPrinter();
        await pump(tester);

        await open(tester, 'Tap the printer');
        expect(
          find.text('Hold your phone against the printer…'),
          findsOneWidget,
        );

        backend.nfc.tap('192.168.1.40');
        await tester.pumpAndSettle();

        expect(find.text('Found it'), findsOneWidget);
      });

      testWidgets('can be cancelled', (tester) async {
        await pump(tester);
        await open(tester, 'Tap the printer');

        await tester.tap(find.text('Cancel'));
        await settle(tester);

        expect(find.text('Tap the printer'), findsOneWidget);
        expect(backend.nfc.cancelled, isTrue);
      });

      testWidgets('says when the tag has nothing readable', (tester) async {
        await pump(tester);
        await open(tester, 'Tap the printer');

        backend.nfc.tap(null);
        await settle(tester);

        expect(
          find.textContaining('nothing PrinterHub can read'),
          findsOneWidget,
        );
      });

      testWidgets('says when the tag could not be read', (tester) async {
        await pump(tester);
        await open(tester, 'Tap the printer');

        backend.nfc.fail(StateError('tag lost'));
        await settle(tester);

        expect(find.textContaining('could not be read'), findsOneWidget);
      });
    });

    group('by Wi-Fi Direct', () {
      testWidgets('gives the steps, then finds the printer at the gateway', (
        tester,
      ) async {
        backend
          ..plugInPrinter()
          ..wifi.gateway = '192.168.223.1';
        await pump(tester);

        await open(tester, 'Wi-Fi Direct');
        expect(find.text('Connect with Wi-Fi Direct'), findsOneWidget);
        expect(
          find.textContaining('usually starts with DIRECT'),
          findsOneWidget,
        );
        expect(find.textContaining('may have no internet'), findsOneWidget);

        await tester.ensureVisible(find.text('Find the printer'));
        await tester.tap(find.text('Find the printer'));
        await tester.pumpAndSettle();

        expect(find.text('Found it'), findsOneWidget);
      });

      testWidgets('says when the phone has not joined the printer yet', (
        tester,
      ) async {
        await pump(tester);
        await open(tester, 'Wi-Fi Direct');

        await tester.ensureVisible(find.text('Find the printer'));
        await tester.tap(find.text('Find the printer'));
        await settle(tester);

        expect(
          find.textContaining("does not seem to be on the printer's Wi-Fi"),
          findsOneWidget,
        );
      });

      testWidgets('names the network and password from a scanned code', (
        tester,
      ) async {
        await pump(tester);
        await open(tester, 'Scan a code');

        backend.scanCode('WIFI:T:WPA;S:DIRECT-AB-C7130;P:secret123;;');
        await settle(tester);

        expect(find.textContaining('join DIRECT-AB-C7130'), findsOneWidget);
        expect(find.text('Password: secret123'), findsOneWidget);
      });
    });

    group('by Bluetooth', () {
      const sighting = BluetoothSighting(
        id: '1',
        name: 'Xerox C7130',
        signal: -40,
      );

      testWidgets('lists the printers near the phone, nearest first', (
        tester,
      ) async {
        await pump(tester);
        await open(tester, 'Find by Bluetooth');
        expect(find.text('Looking for printers near you…'), findsOneWidget);

        backend.bluetooth.see(const [
          BluetoothSighting(id: '2', name: 'HP LaserJet', signal: -70),
          BluetoothSighting(id: '3', name: 'Canon', signal: -90),
          sighting,
        ]);
        await settle(tester);

        expect(find.text('Right beside you'), findsOneWidget);
        expect(find.text('In the room'), findsOneWidget);
        expect(find.text('Further away'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Xerox C7130')).dy,
          lessThan(tester.getTopLeft(find.text('HP LaserJet')).dy),
        );
      });

      testWidgets('reaches the picked printer over the network', (
        tester,
      ) async {
        backend.plugInPrinter();
        await pump(tester);
        backend.nearby.announce(const [_announced]);
        await open(tester, 'Find by Bluetooth');
        backend.bluetooth.see(const [sighting]);
        await settle(tester);

        await tester.tap(find.text('Xerox C7130'));
        await tester.pumpAndSettle();

        expect(find.text('Found it'), findsOneWidget);
      });

      testWidgets('says when the picked printer is not on the network', (
        tester,
      ) async {
        await pump(tester);
        await open(tester, 'Find by Bluetooth');
        backend.bluetooth.see(const [sighting]);
        await settle(tester);

        await tester.tap(find.text('Xerox C7130'));
        await settle(tester);

        expect(
          find.textContaining('Xerox C7130 is nearby, but it is not on your'),
          findsOneWidget,
        );
      });
    });
  });
}
