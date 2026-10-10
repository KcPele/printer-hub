import 'package:api_client/testing.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/copy/copy.dart';
import 'package:printerhub/printers/printers.dart';

import '../../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';

void main() {
  late TestBackend backend;
  late MockGoRouter router;
  late PrintersCubit printers;

  setUp(() async {
    backend = TestBackend()
      ..printerList = [printerBody()]
      ..plugInPrinter();
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
    final listed = await tester.runAsync(() => backend.printers.list(_org));
    printers.emit(
      PrintersState(status: PrintersStatus.ready, printers: listed!),
    );
    await tester.pumpApp(
      CopyPage(printerId: id),
      backend: backend,
      printersCubit: printers,
      router: router,
    );
    await tester.pumpAndSettle();
  }

  /// Lets the scanner, the files, and the printer, which take real time,
  /// get on until the copy is over.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    for (var i = 0; i < 200; i++) {
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pump();
    await tester.tap(target);
  }

  testWidgets('says how many and how, copies, and says it is done', (
    tester,
  ) async {
    await pump(tester);

    expect(find.textContaining('Put the page on the glass'), findsOneWidget);
    await tester.tap(find.byTooltip('One more'));
    await tester.pump();
    await tester.tap(find.byTooltip('One more'));
    await tester.pump();
    await tester.tap(find.byTooltip('One fewer'));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    await press(tester, find.text('Colour'));
    await tester.pump();
    await press(tester, find.text('The feeder'));
    await tester.pump();

    await press(tester, find.widgetWithText(FilledButton, 'Copy'));
    await settle(tester);

    expect(find.text('Copied'), findsOneWidget);
    expect(find.textContaining('2 copies'), findsOneWidget);
    expect(backend.scansStarted.single, contains('Feeder'));

    await press(tester, find.text('Copy something else'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Copy'), findsOneWidget);
  });

  testWidgets('leaves with Done', (tester) async {
    await pump(tester);
    await press(tester, find.widgetWithText(FilledButton, 'Copy'));
    await settle(tester);

    expect(find.textContaining('Your copy is waiting'), findsOneWidget);
    await press(tester, find.widgetWithText(FilledButton, 'Done'));

    verify(router.pop).called(1);
  });

  testWidgets('says where it has got to, and can be stopped', (tester) async {
    backend.scanPages = [tinyJpeg, tinyJpeg, tinyJpeg];
    await pump(tester);
    await press(tester, find.text('The feeder'));
    await tester.pump();

    await press(tester, find.widgetWithText(FilledButton, 'Copy'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('Scanning'), findsOneWidget);
    // It cannot be walked away from while it is at work.
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);

    await tester.tap(find.text('Stop'));
    await settle(tester);

    expect(find.widgetWithText(FilledButton, 'Copy'), findsOneWidget);
    expect(backend.printed, isEmpty);
  });

  testWidgets('says why a copy stopped', (tester) async {
    backend
      ..scannerRefuses = 409
      ..scannerFeeder = 'ScannerAdfEmpty';
    await pump(tester);
    await press(tester, find.text('The feeder'));
    await tester.pump();

    await press(tester, find.widgetWithText(FilledButton, 'Copy'));
    await settle(tester);

    expect(find.textContaining('feeder is empty'), findsOneWidget);
  });

  testWidgets('says what the backend said when it will not record a copy', (
    tester,
  ) async {
    backend.fail('POST /organizations/$_org/jobs', 403, 'permission.denied');
    await pump(tester);

    await press(tester, find.widgetWithText(FilledButton, 'Copy'));
    await settle(tester);

    expect(find.byType(AppNotice), findsOneWidget);
  });

  testWidgets('shows only the choices the printer has', (tester) async {
    final body = printerBody();
    final capabilities = body['capabilities']! as Map<String, Object?>;
    backend.printerList = [
      {
        ...body,
        'capabilities': {
          ...capabilities,
          'print': {
            ...capabilities['print']! as Map<String, Object?>,
            'color': false,
          },
          'scan': {
            ...capabilities['scan']! as Map<String, Object?>,
            'sources': ['platen'],
          },
        },
      },
    ];
    await pump(tester);

    expect(find.text('Colour'), findsNothing);
    expect(find.text('Copy from'), findsNothing);
    expect(find.text('Copies'), findsOneWidget);
  });

  testWidgets('says when a printer is no longer in the workspace', (
    tester,
  ) async {
    await pump(tester, id: 'gone');

    expect(
      find.text('This printer is no longer in the workspace.'),
      findsOneWidget,
    );
  });
}
