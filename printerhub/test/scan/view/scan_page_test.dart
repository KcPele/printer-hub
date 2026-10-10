import 'package:api_client/testing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printer_protocols/testing.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/print/print.dart';
import 'package:printerhub/printers/printers.dart';
import 'package:printerhub/scan/scan.dart';
import 'package:printerhub/workspace/workspace.dart';

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

  Future<void> pump(
    WidgetTester tester, {
    String printerId = 'printer-1',
  }) async {
    final listed = await tester.runAsync(() => backend.printers.list(_org));
    printers.emit(
      PrintersState(status: PrintersStatus.ready, printers: listed!),
    );
    await tester.pumpApp(
      ScanPage(printerId: printerId),
      backend: backend,
      printersCubit: printers,
      router: router,
    );
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pump();
    await tester.tap(target);
  }

  /// Lets the scanner and the phone's files, which take real time, and
  /// the screen, which takes the test's, get on until [done].
  Future<void> until(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// Waits until nothing is at work any more.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await until(
      tester,
      () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
    );
    await tester.pumpAndSettle();
  }

  /// Presses Scan and lets the scanner, and the files it writes, finish.
  Future<void> scan(WidgetTester tester, {String button = 'Scan'}) async {
    await press(
      tester,
      button == 'Scan'
          ? find.widgetWithText(FilledButton, 'Scan')
          : find.text(button),
    );
    await settle(tester);
  }

  ScanCubit cubitOf(WidgetTester tester) =>
      BlocProvider.of<ScanCubit>(tester.element(find.byType(ScanView)));

  group('ScanPage', () {
    testWidgets('offers what the scanner can do', (tester) async {
      await pump(tester);

      expect(find.text('How to scan it'), findsOneWidget);
      expect(find.text('The glass'), findsOneWidget);
      expect(find.text('The feeder'), findsOneWidget);
      expect(find.text('Colour'), findsOneWidget);
      // Both sides is for the feeder.
      expect(find.text('Both sides'), findsNothing);
      expect(find.text('Standard (300 dpi)'), findsOneWidget);
      expect(find.text('A4'), findsOneWidget);
      expect(find.text('One PDF'), findsOneWidget);
    });

    testWidgets('says when a printer is no longer in the workspace', (
      tester,
    ) async {
      await pump(tester, printerId: 'gone');

      expect(find.byType(ScanView), findsNothing);
      expect(find.textContaining('no longer'), findsOneWidget);
    });

    testWidgets('shows only what a simpler scanner offers', (tester) async {
      final body = printerBody();
      final capabilities = body['capabilities']! as Map<String, Object?>;
      backend.printerList = [
        {
          ...body,
          'capabilities': {
            ...capabilities,
            'scan': {
              ...capabilities['scan']! as Map<String, Object?>,
              'sources': ['platen'],
              'color_modes': ['grayscale'],
              'resolutions_dpi': [300],
              'max_width_mm': 150.0,
              'max_height_mm': 212.0,
            },
          },
        },
      ];

      await pump(tester);

      expect(find.text('The glass'), findsNothing);
      expect(find.text('Colour'), findsNothing);
      expect(find.text('Detail'), findsNothing);
      expect(find.text('Paper size'), findsNothing);
      expect(find.text('Keep it as'), findsOneWidget);
    });

    testWidgets('shows what is left when a scanner has said nothing', (
      tester,
    ) async {
      backend.printerList = [
        {...printerBody(), 'capabilities': null},
      ];

      await pump(tester);

      expect(find.text('The glass'), findsNothing);
      expect(find.text('Paper size'), findsOneWidget);
      expect(find.text('Keep it as'), findsOneWidget);
    });

    testWidgets('changes each choice', (tester) async {
      await pump(tester);

      await tester.tap(find.text('The feeder'));
      await tester.pump();
      await press(tester, find.text('Both sides'));
      await tester.pump();
      await press(tester, find.text('Colour'));
      await tester.pump();

      await press(tester, find.text('Standard (300 dpi)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fine (600 dpi)').last);
      await tester.pumpAndSettle();

      await press(tester, find.text('A4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A5').last);
      await tester.pumpAndSettle();

      await press(tester, find.text('One PDF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pictures, one a page').last);
      await tester.pumpAndSettle();

      final choices = cubitOf(tester).state.choices;
      expect(choices.source, 'adf');
      expect(choices.duplex, isTrue);
      expect(choices.color, 'grayscale');
      expect(choices.resolutionDpi, 600);
      expect(choices.mediaSize, 'iso_a5_148x210mm');
      expect(choices.format, 'image/jpeg');
    });

    testWidgets('scans, and shows the page that arrived', (tester) async {
      await pump(tester);

      await scan(tester);

      expect(find.text('Pages'), findsOneWidget);
      expect(find.text('Page 1'), findsOneWidget);
      expect(find.text('Scan more pages'), findsOneWidget);
      // One page has nothing to be moved past.
      expect(find.textContaining('Hold and drag'), findsNothing);
      expect(backend.jobList.single['status'], 'completed');
    });

    testWidgets('says where the scan has got to, and stops it', (tester) async {
      backend.scanPages = [tinyJpeg, tinyJpeg, tinyJpeg];
      var asked = 0;
      final behaving = backend.device.device;
      backend.device.device = (request) async {
        // The scanner takes its time over the second page.
        if (request.uri.path.endsWith('NextDocument') && ++asked == 2) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        return await behaving(request);
      };
      await pump(tester);
      await tester.tap(find.text('The feeder'));
      await tester.pump();

      await press(tester, find.widgetWithText(FilledButton, 'Scan'));
      await tester.pump();
      expect(find.text('Reaching the scanner…'), findsOneWidget);

      final onePage = find.text('Scanning… 1 page so far');
      await until(tester, () => onePage.evaluate().isNotEmpty);
      expect(onePage, findsOneWidget);

      await tester.tap(find.text('Stop scanning'));
      await settle(tester);

      expect(find.text('Pages'), findsOneWidget);
      expect(backend.jobList.single['status'], 'cancelled');
    });

    testWidgets('says scanning before the first page is in', (tester) async {
      final behaving = backend.device.device;
      backend.device.device = (request) async {
        if (request.uri.path.endsWith('NextDocument')) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        return await behaving(request);
      };
      await pump(tester);

      await press(tester, find.widgetWithText(FilledButton, 'Scan'));
      final scanning = find.text('Scanning…');
      await until(tester, () => scanning.evaluate().isNotEmpty);

      expect(scanning, findsOneWidget);
      await settle(tester);
    });

    testWidgets('says why a scan did not start', (tester) async {
      backend
        ..scannerRefuses = 409
        ..scannerFeeder = 'ScannerAdfEmpty';
      await pump(tester);
      await tester.tap(find.text('The feeder'));
      await tester.pump();

      await scan(tester);

      expect(find.textContaining('The feeder is empty'), findsOneWidget);
      expect(find.text('How to scan it'), findsOneWidget);
    });

    testWidgets('says why the backend will not record the scan', (
      tester,
    ) async {
      backend.fail(
        'POST /organizations/$_org/jobs',
        403,
        'permission.denied',
        detail: 'Your role does not allow this action.',
      );
      await pump(tester);

      await scan(tester);

      expect(find.text('Your role does not allow this action.'), findsOne);
    });

    testWidgets('keeps the pages when a later scan fails, and says so', (
      tester,
    ) async {
      await pump(tester);
      await scan(tester);
      backend
        ..unplugPrinter()
        ..fail(
          'POST /organizations/$_org/jobs',
          403,
          'permission.denied',
          detail: 'Your role does not allow this action.',
        );

      await scan(tester, button: 'Scan more pages');
      expect(find.text('Your role does not allow this action.'), findsOne);

      backend.routes.clear();
      await scan(tester, button: 'Scan more pages');

      expect(find.text('Page 1'), findsOneWidget);
      expect(
        find.textContaining('The pages that arrived are kept.'),
        findsOneWidget,
      );
    });

    testWidgets('adds pages, moves them, and takes one out', (tester) async {
      await pump(tester);
      await scan(tester);

      await scan(tester, button: 'Scan more pages');
      expect(find.text('Page 2'), findsOneWidget);
      expect(find.textContaining('Hold and drag'), findsOneWidget);
      final [first, second] = cubitOf(tester).state.pages;

      // Held, then dragged below the other.
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Page 1')),
      );
      await tester.pump(const Duration(seconds: 1));
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(cubitOf(tester).state.pages, [second, first]);

      await tester.tap(find.byTooltip('Remove this page').first);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(cubitOf(tester).state.pages, [first]);
      expect(find.text('Page 2'), findsNothing);
    });

    testWidgets('scans the two sides of an ID card onto one page', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Lay the card face down'), findsNothing);

      await press(tester, find.text('ID card'));
      await tester.pumpAndSettle();

      // A card goes on the glass, and comes out as one PDF.
      expect(find.text('The feeder'), findsNothing);
      expect(find.text('Keep it as'), findsNothing);
      expect(find.text('Paper size'), findsOneWidget);
      expect(find.textContaining('Lay the card face down'), findsOneWidget);

      await scan(tester, button: 'Scan the front');
      expect(find.text('Front'), findsOneWidget);
      expect(find.textContaining('Turn the card over'), findsOneWidget);
      expect(backend.scansStarted.single, contains('Platen'));

      await scan(tester, button: 'Scan the back');
      expect(find.text('Back'), findsOneWidget);
      expect(find.textContaining('Turn the card over'), findsNothing);
      expect(find.text('Scan another card'), findsOneWidget);

      await press(tester, find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      expect(find.text('Your scan is ready'), findsOneWidget);
      expect(cubitOf(tester).state.files.single.path, endsWith('.pdf'));
    });

    testWidgets('does not offer an ID card on a scanner with no glass', (
      tester,
    ) async {
      final body = printerBody();
      final capabilities = body['capabilities']! as Map<String, Object?>;
      backend.printerList = [
        {
          ...body,
          'capabilities': {
            ...capabilities,
            'scan': {
              ...capabilities['scan']! as Map<String, Object?>,
              'sources': ['adf'],
            },
          },
        },
      ];

      await pump(tester);

      expect(find.text('ID card'), findsNothing);
    });

    group('with the phone’s camera switched on', () {
      Future<void> pumpWithCamera(WidgetTester tester) async {
        backend.features = {'camera_scan': true};
        await pump(tester);
        await tester.runAsync(
          BlocProvider.of<FeaturesCubit>(tester.element(find.byType(ScanView)))
              .load,
        );
        await tester.pump();
      }

      /// Presses [button] and lets the camera, which writes files, finish.
      Future<void> take(WidgetTester tester, String button) async {
        await press(tester, find.text(button));
        await until(tester, () => find.text('Pages').evaluate().isNotEmpty);
        await tester.pumpAndSettle();
      }

      testWidgets('takes pages beside the scanner’s, and says which are '
          'which', (tester) async {
        await pumpWithCamera(tester);
        await scan(tester);
        expect(find.text("From your phone's camera"), findsNothing);

        await press(tester, find.text('Add pages with the camera'));
        await until(tester, () => find.text('Page 2').evaluate().isNotEmpty);
        await tester.pumpAndSettle();

        expect(find.text("From your phone's camera"), findsOneWidget);
        expect(find.text('Scan more pages'), findsOneWidget);
      });

      testWidgets('starts a scan from the camera', (tester) async {
        await pumpWithCamera(tester);

        await take(tester, "Use your phone's camera");

        expect(find.text('Page 1'), findsOneWidget);
        expect(find.text("From your phone's camera"), findsOneWidget);
        expect(backend.scansStarted, isEmpty);
      });

      testWidgets('is not offered for an ID card', (tester) async {
        await pumpWithCamera(tester);
        expect(find.text("Use your phone's camera"), findsOneWidget);

        await press(tester, find.text('ID card'));
        await tester.pumpAndSettle();

        expect(find.text("Use your phone's camera"), findsNothing);
      });

      testWidgets('scans for a printer that has no scanner', (tester) async {
        backend.printerList = [printerBody(scans: false)];
        await pumpWithCamera(tester);

        expect(find.text('This printer has no scanner.'), findsOneWidget);
        expect(find.text('How to scan it'), findsNothing);

        backend.camera.fails = true;
        await press(tester, find.text("Use your phone's camera"));
        await until(
          tester,
          () => find.textContaining('could not be used').evaluate().isNotEmpty,
        );
        expect(find.textContaining('could not be used'), findsOneWidget);

        backend.camera.fails = false;
        await take(tester, "Use your phone's camera");

        expect(find.text("From your phone's camera"), findsOneWidget);
        // Nothing more can come from a scanner that is not there.
        expect(find.text('Scan more pages'), findsNothing);
        expect(find.text('Add pages with the camera'), findsOneWidget);
      });
    });

    group('with the phone alone', () {
      Future<void> pumpPhoneOnly(WidgetTester tester) async {
        backend.features = {'camera_scan': true};
        final listed = await tester.runAsync(() => backend.printers.list(_org));
        printers.emit(
          PrintersState(status: PrintersStatus.ready, printers: listed!),
        );
        await tester.pumpApp(
          const ScanPage(),
          backend: backend,
          printersCubit: printers,
          router: router,
        );
        await tester.pumpAndSettle();
        await tester.runAsync(
          BlocProvider.of<FeaturesCubit>(tester.element(find.byType(ScanView)))
              .load,
        );
        await tester.pump();
      }

      Future<void> takeAndSave(WidgetTester tester) async {
        await press(tester, find.text("Use your phone's camera"));
        await until(tester, () => find.text('Pages').evaluate().isNotEmpty);
        await tester.pumpAndSettle();
        await press(tester, find.widgetWithText(FilledButton, 'Save'));
        await settle(tester);
      }

      testWidgets('scans with the camera, and prints on a printer of the '
          'workspace', (tester) async {
        await pumpPhoneOnly(tester);

        expect(find.text('Scan with your phone'), findsOneWidget);
        expect(find.text('This printer has no scanner.'), findsNothing);
        expect(find.text('How to scan it'), findsNothing);

        await press(tester, find.text("Use your phone's camera"));
        await until(tester, () => find.text('Pages').evaluate().isNotEmpty);
        await tester.pumpAndSettle();
        expect(find.text("From your phone's camera"), findsOneWidget);
        expect(find.text('Scan more pages'), findsNothing);

        await press(tester, find.widgetWithText(FilledButton, 'Save'));
        await settle(tester);
        await press(tester, find.text('Print it'));
        await tester.pumpAndSettle();

        final pushed = verify(
          () => router.push<Object?>(
            AppRoutes.printOn('printer-1'),
            extra: captureAny(named: 'extra'),
          ),
        )..called(1);
        expect(pushed.captured.single, isA<PickedDocument>());
      });

      testWidgets('asks which printer when the workspace has several, and '
          'prints nothing when none is picked', (tester) async {
        backend.printerList = [
          printerBody(),
          printerBody(id: 'printer-2', name: 'Back office'),
        ];
        await pumpPhoneOnly(tester);
        await takeAndSave(tester);

        await press(tester, find.text('Print it'));
        await tester.pumpAndSettle();
        expect(find.text('Which printer?'), findsOneWidget);
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();

        verifyNever(
          () => router.push<Object?>(any(), extra: any(named: 'extra')),
        );
      });

      testWidgets('makes a document of pictures chosen from the phone', (
        tester,
      ) async {
        backend.picker.pictures = [
          pickedPicture(backend.scans, name: 'One.jpg'),
          pickedPicture(backend.scans, name: 'Two.jpg'),
        ];
        await pumpPhoneOnly(tester);

        await press(tester, find.text('Choose pictures'));
        await until(tester, () => find.text('Pages').evaluate().isNotEmpty);
        await tester.pumpAndSettle();
        expect(find.text('Page 2'), findsOneWidget);
        expect(find.text("From your phone's camera"), findsNothing);

        backend.picker.pictures = [
          pickedPicture(backend.scans, name: 'Three.jpg'),
        ];
        await press(tester, find.text('Add pictures'));
        await until(tester, () => find.text('Page 3').evaluate().isNotEmpty);
        expect(find.text('Page 3'), findsOneWidget);
      });

      testWidgets('asks for pictures at once when opened for them', (
        tester,
      ) async {
        backend.picker.pictures = [pickedPicture(backend.scans)];
        await tester.pumpApp(
          const ScanPage(startWithPictures: true),
          backend: backend,
          printersCubit: printers,
          router: router,
        );
        await until(tester, () => find.text('Pages').evaluate().isNotEmpty);

        expect(find.text('Page 1'), findsOneWidget);
      });

      testWidgets('does not offer to print in a workspace with no printer', (
        tester,
      ) async {
        backend.printerList = [];
        await pumpPhoneOnly(tester);
        await takeAndSave(tester);

        expect(find.text('Your scan is ready'), findsOneWidget);
        expect(find.text('Print it'), findsNothing);
        expect(find.text('Keep in your workspace'), findsOneWidget);
      });
    });

    testWidgets('offers no camera on a phone without one, or in a workspace '
        'that has it switched off', (tester) async {
      await pump(tester);
      expect(find.text("Use your phone's camera"), findsNothing);

      backend.printerList = [printerBody(scans: false)];
      backend.camera.available = false;
      backend.features = {'camera_scan': true};
      await pump(tester);

      expect(find.text('This printer has no scanner.'), findsOneWidget);
      expect(find.text("Use your phone's camera"), findsNothing);
    });

    testWidgets('names the scan, saves it, and shares it', (tester) async {
      await pump(tester);
      await scan(tester);

      await tester.enterText(find.byType(TextFormField), 'Receipts');
      await press(tester, find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      expect(find.text('Your scan is ready'), findsOneWidget);
      expect(find.text('Receipts.pdf'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Share'));
      await tester.pump();
      expect(backend.sharer.shared.single.name, 'Receipts');

      await press(tester, find.text('Done'));
      verify(router.pop).called(1);
    });

    testWidgets('prints a saved scan on the printer it was made on', (
      tester,
    ) async {
      await pump(tester);
      await scan(tester);
      await press(tester, find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      await tester.tap(find.text('Print it'));

      final handed = verify(
        () => router.push<Object?>(
          AppRoutes.printOn('printer-1'),
          extra: captureAny(named: 'extra'),
        ),
      ).captured.single;
      expect(
        handed,
        isA<PickedDocument>()
            .having((d) => d.mimeType, 'type', 'application/pdf')
            .having((d) => d.name, 'name', endsWith('.pdf')),
      );
    });

    testWidgets('does not offer to print several pictures, or on a device '
        'that only scans', (tester) async {
      await pump(tester);
      await tester.tap(find.text('The feeder'));
      await tester.pump();
      await press(tester, find.text('One PDF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pictures, one a page').last);
      await tester.pumpAndSettle();
      backend.scanPages = [tinyJpeg, tinyJpeg];
      await scan(tester);
      await press(tester, find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Print it'), findsNothing);
    });

    testWidgets('does not offer to print on a device that only scans', (
      tester,
    ) async {
      final body = printerBody();
      final capabilities = body['capabilities']! as Map<String, Object?>;
      backend.printerList = [
        {
          ...body,
          'capabilities': {
            ...capabilities,
            'print': {
              ...capabilities['print']! as Map<String, Object?>,
              'supported': false,
            },
          },
        },
      ];
      await pump(tester);
      await scan(tester);
      await press(tester, find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      expect(find.text('Print it'), findsNothing);
    });

    testWidgets('keeps a saved scan in the workspace', (tester) async {
      await pump(tester);
      await scan(tester);
      await press(tester, find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      await tester.tap(find.text('Keep in your workspace'));
      await tester.pump();
      // On its way: nothing else can be done to the scan.
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Back to the pages'),
            )
            .onPressed,
        isNull,
      );
      await settle(tester);

      expect(find.text('Kept in your workspace'), findsOneWidget);
      expect(find.text('Keep in your workspace'), findsNothing);
      expect(backend.documentList.single['upload_status'], 'uploaded');
    });

    testWidgets('reads the words of a kept scan in a workspace that has it '
        'switched on, and says so', (tester) async {
      backend.features = {'local_ocr': true};
      await pump(tester);
      await tester.runAsync(
        BlocProvider.of<FeaturesCubit>(tester.element(find.byType(ScanView)))
            .load,
      );
      await scan(tester);
      await press(tester, find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      await tester.tap(find.text('Keep in your workspace'));
      await settle(tester);

      expect(find.text('Kept in your workspace'), findsOneWidget);
      expect(find.textContaining('Its words were read'), findsOneWidget);
      expect(
        backend.lastBody('POST /organizations/$_org/documents')['ocr_text'],
        'Invoice 42',
      );
    });

    testWidgets('says when the words of a kept scan could not be read', (
      tester,
    ) async {
      backend
        ..features = {'local_ocr': true}
        ..textReader.fails = true;
      await pump(tester);
      await tester.runAsync(
        BlocProvider.of<FeaturesCubit>(tester.element(find.byType(ScanView)))
            .load,
      );
      await scan(tester);
      await press(tester, find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      await tester.tap(find.text('Keep in your workspace'));
      await settle(tester);

      expect(find.text('Kept in your workspace'), findsOneWidget);
      expect(find.textContaining('could not be read'), findsOneWidget);
    });

    testWidgets('says when a scan did not reach the workspace', (tester) async {
      backend.storage.broken = true;
      await pump(tester);
      await scan(tester);
      await press(tester, find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      await tester.tap(find.text('Keep in your workspace'));
      await settle(tester);

      expect(
        find.textContaining('did not reach your workspace'),
        findsOneWidget,
      );
      expect(find.text('Keep in your workspace'), findsOneWidget);
    });

    testWidgets('says why the workspace will not keep a scan', (tester) async {
      backend.fail(
        'POST /organizations/$_org/documents',
        403,
        'document.cloud_storage_disabled',
        detail: 'This organization keeps documents on devices only.',
      );
      await pump(tester);
      await scan(tester);
      await press(tester, find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      await tester.tap(find.text('Keep in your workspace'));
      await settle(tester);

      expect(
        find.text('This organization keeps documents on devices only.'),
        findsOneWidget,
      );
    });

    testWidgets('goes back from a saved scan to its pages', (tester) async {
      await pump(tester);
      await scan(tester);
      await press(tester, find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      await tester.tap(find.text('Back to the pages'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(find.text('Pages'), findsOneWidget);
    });

    testWidgets('says when the scan cannot be kept on the phone', (
      tester,
    ) async {
      await pump(tester);
      await scan(tester);
      // Nowhere is left to write to.
      await tester.runAsync(() async {
        final page = cubitOf(tester).state.pages.single.file;
        final bytes = page.readAsBytesSync();
        backend.scans.deleteSync(recursive: true);
        // The page itself is put back, out of the way of the test's end.
        backend.scans.createSync();
        page.writeAsBytesSync(bytes);
        backend.scans.deleteSync(recursive: true);
      });

      await press(tester, find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      expect(
        find.textContaining('could not be kept on your phone'),
        findsOneWidget,
      );
      expect(find.textContaining('are kept'), findsNothing);
    });

    testWidgets('starts over', (tester) async {
      await pump(tester);
      await scan(tester);

      await press(tester, find.text('Start over'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(find.text('How to scan it'), findsOneWidget);
    });

    testWidgets('shows a page the scanner made as a PDF', (tester) async {
      final behaving = backend.device.device;
      backend.device.device = (request) async {
        final answer = await behaving(request);
        if (!request.uri.path.endsWith('NextDocument')) return answer;
        return FakeAnswer(
          answer.statusCode,
          body: answer.body,
          headers: const {'content-type': 'application/pdf'},
        );
      };
      await pump(tester);

      await scan(tester);

      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
    });

    testWidgets('shows a page it cannot draw as a page all the same', (
      tester,
    ) async {
      backend.scanPages = ['not a picture'.codeUnits];
      await pump(tester);

      await scan(tester);
      final placeholder = find.byIcon(Icons.image_outlined);
      await until(tester, () => placeholder.evaluate().isNotEmpty);

      expect(placeholder, findsOneWidget);
      expect(find.text('Page 1'), findsOneWidget);
    });

    testWidgets('cannot be left while the scanner is at work', (tester) async {
      await pump(tester);
      PopScope<Object?> scope() =>
          tester.widget(find.byWidgetPredicate((widget) => widget is PopScope));
      expect(scope().canPop, isTrue);

      await press(tester, find.widgetWithText(FilledButton, 'Scan'));
      await tester.pump();
      expect(scope().canPop, isFalse);

      await settle(tester);
      expect(scope().canPop, isTrue);
    });
  });
}
