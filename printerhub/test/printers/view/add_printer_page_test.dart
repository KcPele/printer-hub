import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printer_protocols/printer_protocols.dart';
import 'package:printer_protocols/testing.dart';
import 'package:printerhub/printers/printers.dart';

import '../../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';

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

    Future<void> pump(WidgetTester tester) {
      return tester.pumpApp(
        const AddPrinterPage(),
        backend: backend,
        printersCubit: printers,
        router: router,
      );
    }

    Future<void> find_(WidgetTester tester, String address) async {
      await tester.enterText(find.byType(TextField).first, address);
      await tester.tap(find.text('Find printer'));
      await tester.pumpAndSettle();
    }

    testWidgets('asks for the printer address', (tester) async {
      await pump(tester);

      expect(find.text('Add a printer'), findsOneWidget);
      expect(find.text('Printer address'), findsOneWidget);
      expect(find.text('Find printer'), findsOneWidget);
    });

    testWidgets('says when the address is not one, and keeps what was typed', (
      tester,
    ) async {
      await pump(tester);

      await find_(tester, 'two words');

      expect(
        find.textContaining('does not look like an address'),
        findsOneWidget,
      );
      expect(find.text('two words'), findsOneWidget);
    });

    testWidgets('says when nothing answers', (tester) async {
      await pump(tester);

      await find_(tester, '192.168.1.99');

      expect(find.textContaining('Nothing answered'), findsOneWidget);
      expect(find.text('192.168.1.99'), findsOneWidget);
    });

    testWidgets('says when what answers is not a printer', (tester) async {
      backend.device.device = (_) => const FakeAnswer(404);
      await pump(tester);

      await find_(tester, '192.168.1.1');

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
      await tester.enterText(find.byType(TextField).first, '10.0.0.7:631');

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Asking the printer'), findsOneWidget);

      answer.complete();
      await tester.pumpAndSettle();
      expect(find.text('Find printer'), findsOneWidget);
    });

    group('once the printer is found', () {
      Future<void> found(WidgetTester tester) async {
        backend.plugInPrinter();
        await pump(tester);
        await find_(tester, '10.0.0.7');
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

      testWidgets('goes back to the address to try another', (tester) async {
        await found(tester);

        await tester.ensureVisible(find.text('Try another address'));
        await tester.tap(find.text('Try another address'));
        await tester.pumpAndSettle();

        expect(find.text('Find printer'), findsOneWidget);
        expect(find.text('10.0.0.7'), findsOneWidget);
      });
    });
  });
}
