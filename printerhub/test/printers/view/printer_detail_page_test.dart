import 'dart:async';

import 'package:api_client/testing.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/printers/printers.dart';
import 'package:printerhub/printers/widgets/pairing_code_sheet.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';

void main() {
  group('PrinterDetailPage', () {
    late TestBackend backend;
    late MockGoRouter router;
    late PrintersCubit printers;

    setUp(() async {
      backend = TestBackend()..printerList = [printerBody()];
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

    Future<void> pump(WidgetTester tester, {String id = 'printer-1'}) async {
      await tester.runAsync(printers.load);
      await tester.pumpApp(
        PrinterDetailPage(printerId: id),
        backend: backend,
        printersCubit: printers,
        router: router,
      );
      await tester.pump();
    }

    Future<void> scrollTo(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('describes the printer and how it is doing', (tester) async {
      backend.plugInPrinter(tonerLevels: {'black': 82, 'cyan': 8, 'drum': -1});
      await pump(tester);

      expect(find.text('Front desk'), findsOneWidget);
      expect(find.text('Xerox VersaLink C7130'), findsOneWidget);
      expect(find.text('Second floor'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);

      await scrollTo(tester, find.text('Supplies'));
      expect(find.byType(SupplyLevelBar), findsNWidgets(3));
      expect(find.text('82%'), findsOneWidget);

      await scrollTo(tester, find.text('What it can do'));
      await scrollTo(tester, find.text('Copies'));
      expect(find.text('Prints in colour'), findsOneWidget);

      await scrollTo(tester, find.text('How it connects'));
      await scrollTo(tester, find.textContaining('ESCL'));
      expect(find.textContaining('IPP  192.168.1.40'), findsOneWidget);
    });

    testWidgets('shows what the printer wants attention for', (tester) async {
      backend.plugInPrinter(
        stateReasons: ['media-jam-error', 'toner-low-warning'],
      );
      await pump(tester);

      expect(find.text('Needs attention'), findsOneWidget);
      expect(find.text('Paper is jammed'), findsOneWidget);
      expect(find.text('Toner is low'), findsOneWidget);
    });

    testWidgets('shows the backend record before the device has been asked', (
      tester,
    ) async {
      backend.printerList = [
        printerBody(
          location: null,
          alerts: [
            {'code': 'door-open', 'severity': 'error', 'message': null},
          ],
          consumables: [
            {
              'name': 'Black Toner',
              'kind': 'toner',
              'color': 'black',
              'level_percent': null,
              'state': 'unknown',
            },
          ],
        ),
      ];
      final loaded = await tester.runAsync(() => backend.printers.list(_org));
      printers.emit(
        PrintersState(status: PrintersStatus.ready, printers: loaded!),
      );
      await tester.pumpApp(
        const PrinterDetailPage(printerId: 'printer-1'),
        backend: backend,
        printersCubit: printers,
      );

      expect(find.text('A door or cover is open'), findsOneWidget);
      expect(find.text('Second floor'), findsNothing);
      await scrollTo(tester, find.text('Unknown'));
      expect(find.text('Black Toner'), findsOneWidget);
    });

    testWidgets('asks the printer again on request', (tester) async {
      await pump(tester);
      expect(find.text('Not reachable'), findsOneWidget);
      backend.plugInPrinter();

      await scrollTo(tester, find.text('Check status'));
      await tester.tap(find.text('Check status'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await tester.pumpAndSettle();

      expect(find.text('Ready'), findsOneWidget);
    });

    testWidgets('asks the printer again when pulled down', (tester) async {
      await pump(tester);
      backend.plugInPrinter();

      await tester.fling(
        find.text('Xerox VersaLink C7130'),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('Ready'), findsOneWidget);
    });

    group('removing', () {
      Future<void> askToRemove(WidgetTester tester) async {
        await pump(tester);
        await scrollTo(tester, find.text('Remove printer'));
        await tester.tap(find.text('Remove printer'));
        await tester.pumpAndSettle();
      }

      testWidgets('asks first, and can be cancelled', (tester) async {
        await askToRemove(tester);
        expect(find.text('Remove Front desk?'), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(backend.printerList, hasLength(1));
        verifyNever(router.pop);
      });

      testWidgets('removes the printer and goes back', (tester) async {
        await askToRemove(tester);

        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();

        expect(backend.printerList, isEmpty);
        expect(find.text('Front desk was removed.'), findsOneWidget);
        verify(router.pop).called(1);
      });

      testWidgets('says why the printer could not be removed', (tester) async {
        await askToRemove(tester);
        backend.offline = true;

        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();

        expect(find.textContaining("Can't reach PrinterHub"), findsOneWidget);
        expect(printers.state.printers, hasLength(1));
        verifyNever(router.pop);
      });
    });

    group('sharing with a code', () {
      testWidgets('shows a code another member can scan', (tester) async {
        await pump(tester);

        await scrollTo(tester, find.text('Share with a code'));
        await tester.tap(find.text('Share with a code'));
        await tester.pumpAndSettle();

        expect(find.text('Scan to open this printer'), findsOneWidget);
        expect(find.textContaining('to open Front desk'), findsOneWidget);
        expect(
          tester.widget<QrImageView>(find.byType(QrImageView)).semanticsLabel,
          'Pairing code for Front desk',
        );
        expect(
          backend.sent(
            'POST /organizations/$_org/printers/printer-1/pairing-tokens',
          ),
          hasLength(1),
        );
      });

      testWidgets('says why the code could not be made', (tester) async {
        await pump(tester);
        backend.offline = true;

        await scrollTo(tester, find.text('Share with a code'));
        await tester.tap(find.text('Share with a code'));
        await tester.pumpAndSettle();

        expect(find.byType(QrImageView), findsNothing);
        expect(find.textContaining("Can't reach PrinterHub"), findsOneWidget);
      });

      testWidgets('shows progress while the code is being made', (
        tester,
      ) async {
        await tester.pumpApp(
          Scaffold(
            body: PairingCodeSheet(
              printerName: 'Front desk',
              code: Completer<({String link, DateTime expiresAt})>().future,
            ),
          ),
          backend: backend,
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    testWidgets('says when the printer is no longer in the workspace', (
      tester,
    ) async {
      await pump(tester, id: 'gone');

      expect(
        find.text('This printer is no longer in the workspace.'),
        findsOneWidget,
      );
    });

    testWidgets('leaves out sections it has nothing for', (tester) async {
      backend.printerList = [
        {
          ...printerBody(connections: []),
          'capabilities': null,
          'manufacturer': null,
          'model': null,
        },
      ];
      await pump(tester);

      expect(find.text('Supplies'), findsNothing);
      expect(find.text('What it can do'), findsNothing);
      expect(find.text('How it connects'), findsNothing);
      expect(find.byType(AppIllustration), findsOneWidget);
    });
  });
}
