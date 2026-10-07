import 'package:api_client/testing.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/printers/printers.dart';

import '../../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';

void main() {
  group('PrintersPage', () {
    late TestBackend backend;
    late MockGoRouter router;
    late PrintersCubit cubit;

    setUp(() async {
      backend = TestBackend();
      router = recordingRouter();
      await backend.signedInBefore();
      cubit = PrintersCubit(
        printersRepository: backend.printers,
        organizationId: _org,
        organizationChanges: const Stream.empty(),
      );
    });
    tearDown(() async {
      await cubit.close();
      await backend.close();
    });

    Future<void> pump(WidgetTester tester, {bool load = true}) async {
      if (load) await tester.runAsync(cubit.load);
      await tester.pumpApp(
        const PrintersPage(),
        backend: backend,
        printersCubit: cubit,
        router: router,
      );
      await tester.pump();
    }

    testWidgets('shows progress before the first load', (tester) async {
      await pump(tester, load: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('invites a workspace with no printers to add one', (
      tester,
    ) async {
      await pump(tester);

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No printers yet'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.tap(find.text('Add a printer'));
      verify(() => router.push<Object?>(AppRoutes.addPrinter)).called(1);
    });

    testWidgets('lists the printers with how each is doing', (tester) async {
      backend
        ..printerList = [printerBody(), printerBody(id: 'p2', name: 'Lobby')]
        ..plugInPrinter();
      await pump(tester);

      expect(find.byType(PrinterCard), findsNWidgets(2));
      expect(find.text('Front desk'), findsOneWidget);
      expect(find.text('Lobby'), findsOneWidget);
      expect(find.text('Ready'), findsNWidgets(2));
      expect(find.text('Xerox VersaLink C7130'), findsNWidgets(2));
    });

    testWidgets('opens a printer and offers to add another', (tester) async {
      backend.printerList = [printerBody()];
      await pump(tester);

      await tester.tap(find.text('Front desk'));
      await tester.tap(find.byType(FloatingActionButton));

      verify(() => router.push<Object?>(AppRoutes.printer('printer-1')))
          .called(1);
      verify(() => router.push<Object?>(AppRoutes.addPrinter)).called(1);
    });

    testWidgets('reloads when pulled down', (tester) async {
      backend.printerList = [printerBody()];
      await pump(tester);
      backend.printerList = [printerBody(name: 'Renamed')];

      await tester.fling(find.text('Front desk'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Renamed'), findsOneWidget);
    });

    testWidgets('says why the printers could not be loaded, and retries', (
      tester,
    ) async {
      backend.offline = true;
      await pump(tester);

      expect(find.textContaining("Can't reach PrinterHub"), findsOneWidget);

      backend
        ..offline = false
        ..printerList = [printerBody()];
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Front desk'), findsOneWidget);
    });
  });

  group('PrinterStatusPill', () {
    testWidgets('says a printer is being checked for the first time', (
      tester,
    ) async {
      final backend = TestBackend()..printerList = [printerBody()];
      addTearDown(backend.close);
      await tester.runAsync(backend.signedInBefore);
      final cubit = PrintersCubit(
        printersRepository: backend.printers,
        organizationId: _org,
        organizationChanges: const Stream.empty(),
      );
      addTearDown(cubit.close);
      await tester.pumpApp(
        const PrintersPage(),
        backend: backend,
        printersCubit: cubit,
      );

      // The list arrives, and the printer is asked: one frame in between.
      cubit.emit(
        PrintersState(
          status: PrintersStatus.ready,
          printers:
              await tester.runAsync(() => backend.printers.list(_org)) ?? [],
          checking: const {'printer-1'},
        ),
      );
      await tester.pump();

      expect(find.text('Checking…'), findsOneWidget);
    });

    testWidgets('a card without a tap handler has no arrow', (tester) async {
      final backend = TestBackend()..printerList = [printerBody()];
      addTearDown(backend.close);
      await tester.runAsync(backend.signedInBefore);
      final printers = await tester.runAsync(() => backend.printers.list(_org));

      await tester.pumpApp(
        Scaffold(body: PrinterCard(printer: printers!.single)),
        backend: backend,
      );

      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.text('Front desk'), findsOneWidget);
    });
  });
}
