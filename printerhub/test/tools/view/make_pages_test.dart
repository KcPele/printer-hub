import 'package:api_client/testing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/print/print.dart';
import 'package:printerhub/printers/printers.dart';
import 'package:printerhub/tools/tools.dart';

import '../../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';

void main() {
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

  Future<void> pump(
    WidgetTester tester,
    Widget page, {
    bool withPrinter = true,
  }) async {
    if (withPrinter) {
      final listed = await tester.runAsync(() => backend.printers.list(_org));
      printers.emit(
        PrintersState(status: PrintersStatus.ready, printers: listed!),
      );
    }
    await tester.pumpApp(
      page,
      backend: backend,
      printersCubit: printers,
      router: router,
    );
    await tester.pumpAndSettle();
  }

  /// Lets the files, which take real time, be written.
  Future<void> until(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> make(WidgetTester tester, {String button = 'Make it'}) async {
    final target = find.widgetWithText(FilledButton, button);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    // The button turns while the page is made, so nothing settles.
    await tester.tap(target);
    await tester.pump();
    await until(
      tester,
      () => find.text('Your page is ready').evaluate().isNotEmpty,
    );
    expect(find.text('Your page is ready'), findsOneWidget);
  }

  FilledButton makeButton(WidgetTester tester) =>
      tester.widget(find.widgetWithText(FilledButton, 'Make it'));

  group('CodeSheetPage', () {
    CodeSheetCubit cubitOf(WidgetTester tester) =>
        BlocProvider.of(tester.element(find.byType(CodeSheetView)));

    testWidgets('makes a sign for a link, prints it, and shares it', (
      tester,
    ) async {
      await pump(tester, const CodeSheetPage());
      expect(find.textContaining('Print a sign'), findsOneWidget);
      expect(makeButton(tester).onPressed, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('code-text')),
        'https://example.com/menu',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Heading (optional)'),
        'Our menu',
      );
      await tester.pump();
      await press(tester, find.text('A4'));
      await tester.tap(find.text('Letter').last);
      await tester.pumpAndSettle();

      final choices = cubitOf(tester).state.choices;
      expect(choices.text, 'https://example.com/menu');
      expect(choices.title, 'Our menu');
      expect(choices.paper.name, 'na_letter_8.5x11in');

      await make(tester);
      expect(find.text('Make it again'), findsOneWidget);

      await press(tester, find.widgetWithText(FilledButton, 'Print it'));
      final pushed = verify(
        () => router.push<Object?>(
          AppRoutes.printOn('printer-1'),
          extra: captureAny(named: 'extra'),
        ),
      )..called(1);
      expect(
        (pushed.captured.single as PickedDocument).name,
        startsWith('QR code '),
      );

      await press(tester, find.widgetWithText(OutlinedButton, 'Share'));
      expect(backend.sharer.shared, hasLength(1));
    });

    testWidgets('makes a sign for a Wi-Fi network', (tester) async {
      await pump(tester, const CodeSheetPage());

      await press(tester, find.text('Wi-Fi'));
      expect(find.byKey(const ValueKey('code-text')), findsNothing);
      expect(find.textContaining('never printed in words'), findsOneWidget);
      expect(makeButton(tester).onPressed, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('code-network')),
        'Office',
      );
      await tester.enterText(
        find.byKey(const ValueKey('code-password')),
        'let me in',
      );
      await tester.pump();

      final choices = cubitOf(tester).state.choices;
      expect(choices.wifi, isTrue);
      expect((choices.network, choices.password), ('Office', 'let me in'));
      await make(tester);
    });

    testWidgets('offers sharing only, where there is no printer to print '
        'on', (tester) async {
      await pump(tester, const CodeSheetPage(), withPrinter: false);
      await tester.enterText(find.byKey(const ValueKey('code-text')), 'Hello');
      await tester.pump();

      await make(tester);

      expect(find.widgetWithText(FilledButton, 'Print it'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Share'), findsOneWidget);
    });

    testWidgets('prints nothing when no printer is picked', (tester) async {
      backend.printerList = [
        printerBody(),
        printerBody(id: 'printer-2', name: 'Back office'),
      ];
      await pump(tester, const CodeSheetPage());
      await tester.enterText(find.byKey(const ValueKey('code-text')), 'Hello');
      await tester.pump();
      await make(tester);

      await press(tester, find.widgetWithText(FilledButton, 'Print it'));
      expect(find.text('Which printer?'), findsOneWidget);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      verifyNever(
        () => router.push<Object?>(any(), extra: any(named: 'extra')),
      );
    });
  });

  group('NotePage', () {
    testWidgets('prints what is typed', (tester) async {
      await pump(tester, const NotePage());
      expect(find.textContaining('No file needed'), findsOneWidget);
      expect(makeButton(tester).onPressed, isNull);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Heading (optional)'),
        'Shopping',
      );
      await tester.enterText(
        find.byKey(const ValueKey('note-text')),
        'Milk\nBread',
      );
      await tester.pump();
      await press(tester, find.text('A4'));
      await tester.tap(find.text('Letter').last);
      await tester.pumpAndSettle();

      final choices = BlocProvider.of<NoteCubit>(
        tester.element(find.byType(NoteView)),
      ).state.choices;
      expect((choices.title, choices.text), ('Shopping', 'Milk\nBread'));
      expect(choices.paper.name, 'na_letter_8.5x11in');

      await make(tester);
      await press(tester, find.widgetWithText(OutlinedButton, 'Share'));
      expect(backend.sharer.shared.single.name, startsWith('Note '));
    });
  });

  group('PrintablePage', () {
    PrintableCubit cubitOf(WidgetTester tester) =>
        BlocProvider.of(tester.element(find.byType(PrintableView)));

    testWidgets('makes lined paper as it opens', (tester) async {
      await pump(tester, const PrintablePage());

      expect(find.text('Lined paper'), findsOneWidget);
      expect(find.byTooltip('The month after'), findsNothing);
      await press(tester, find.text('A4'));
      await tester.tap(find.text('Letter').last);
      await tester.pumpAndSettle();
      expect(cubitOf(tester).state.choices.paper.name, 'na_letter_8.5x11in');

      await make(tester);
    });

    testWidgets('makes a calendar for the month chosen', (tester) async {
      await pump(tester, const PrintablePage());
      final today = DateTime.now();

      await press(tester, find.text('Lined paper'));
      await tester.tap(find.text('Calendar for a month').last);
      await tester.pumpAndSettle();
      expect(cubitOf(tester).state.choices.kind, Printable.calendar);

      await press(tester, find.byTooltip('The month after'));
      await press(tester, find.byTooltip('The month after'));
      await press(tester, find.byTooltip('The month before'));
      final next = DateTime(today.year, today.month + 1);
      final choices = cubitOf(tester).state.choices;
      expect((choices.year, choices.month), (next.year, next.month));

      await make(tester);
    });
  });

  group('PagesPerSheetPage', () {
    testWidgets('sets a PDF’s pages several to a sheet', (tester) async {
      await pump(tester, const PagesPerSheetPage());
      expect(find.textContaining('Save paper'), findsOneWidget);
      expect(makeButton(tester).onPressed, isNull);

      await press(tester, find.text('Choose a PDF'));
      expect(find.text('Report.pdf'), findsOneWidget);
      expect(find.text('Choose another'), findsOneWidget);

      await press(tester, find.text('4 to a sheet'));
      await press(tester, find.text('A4'));
      await tester.tap(find.text('Letter').last);
      await tester.pumpAndSettle();
      final choices = BlocProvider.of<PagesPerSheetCubit>(
        tester.element(find.byType(PagesPerSheetView)),
      ).state.choices;
      expect(choices.perSheet, 4);
      expect(choices.paper.name, 'na_letter_8.5x11in');

      await make(tester);
    });

    testWidgets('says when the PDF cannot be read', (tester) async {
      backend.renderer.unreadable = true;
      await pump(tester, const PagesPerSheetPage());
      await press(tester, find.text('Choose a PDF'));

      await tester.tap(find.widgetWithText(FilledButton, 'Make it'));
      await tester.pump();
      await until(
        tester,
        () => find.textContaining('could not be read').evaluate().isNotEmpty,
      );

      expect(find.textContaining('could not be read'), findsOneWidget);
    });
  });
}
