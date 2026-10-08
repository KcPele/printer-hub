import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:api_client/testing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printer_protocols/printer_protocols.dart';
import 'package:printer_protocols/testing.dart';
import 'package:printerhub/print/print.dart';
import 'package:printerhub/printers/printers.dart';

import '../../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';

/// A one-pixel PNG, for a preview that can really be drawn.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8Bw'
  'HwAFBQIAX8jx0gAAAABJRU5ErkJggg==',
);

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
      PrintPage(printerId: printerId),
      backend: backend,
      printersCubit: printers,
      router: router,
    );
    await tester.pumpAndSettle();
  }

  Future<void> chooseFile(WidgetTester tester) async {
    await tester.tap(find.text('Choose a file'));
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, String label) async {
    // The first: a title above may read the same as a button below it.
    final target = label == 'Print'
        ? find.widgetWithText(FilledButton, label)
        : find.text(label).first;
    await tester.ensureVisible(target);
    await tester.pump();
    await tester.tap(target);
  }

  /// Presses Print and moves time on until the screen stops changing, or
  /// for a while when the print does not end by itself.
  Future<void> startPrinting(WidgetTester tester, {bool ends = true}) async {
    await press(tester, 'Print');
    if (ends) {
      await tester.pumpAndSettle();
    } else {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
  }

  /// Makes the printer misbehave for the requests [when] picks out.
  void interfere(bool Function(SentRequest request, int operation) when) {
    final behaving = backend.device.device;
    backend.device.device = (request) {
      final operation = request.method == 'POST'
          ? decodeIpp(request.body).message.code
          : -1;
      if (when(request, operation)) {
        throw PrinterUnreachable(request.uri, 'gone');
      }
      return behaving(request);
    };
  }

  group('PrintPage', () {
    testWidgets('asks for a file first', (tester) async {
      await pump(tester);

      expect(find.text('What would you like to print?'), findsOneWidget);
      expect(find.text('Choose a PDF or a picture from your phone.'), findsOne);
    });

    testWidgets('says when a printer is no longer in the workspace', (
      tester,
    ) async {
      await pump(tester, printerId: 'gone');

      expect(find.byType(PrintView), findsNothing);
      expect(find.textContaining('no longer'), findsOneWidget);
    });

    testWidgets('says it is reading while a file is opened', (tester) async {
      final read = Completer<DocumentPreview>();
      backend.documents = PrintDocuments(
        picker: backend.picker,
        renderer: _SlowRenderer(read.future),
      );
      await pump(tester);

      await tester.tap(find.text('Choose a file'));
      await tester.pump();

      expect(find.text('Reading the document…'), findsOneWidget);

      read.complete(const DocumentPreview(pageCount: 1));
      await tester.pumpAndSettle();
      expect(find.text('1 page'), findsOneWidget);
    });

    testWidgets('says when the file is not one it prints', (tester) async {
      backend.picker.next = pickedPdf(name: 'Budget.xlsx');
      await pump(tester);

      await chooseFile(tester);

      expect(find.textContaining('prints PDFs and pictures'), findsOneWidget);
    });

    testWidgets('says when the file cannot be read', (tester) async {
      backend.renderer.unreadable = true;
      await pump(tester);

      await chooseFile(tester);

      expect(find.textContaining('could not be read'), findsOneWidget);
    });

    testWidgets('shows the document and what the printer offers', (
      tester,
    ) async {
      backend.renderer.firstPage = _png;
      await pump(tester);

      await chooseFile(tester);

      expect(find.text('Report.pdf'), findsOneWidget);
      expect(find.text('2 pages'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Copies'), findsOneWidget);
      expect(find.text('Colour'), findsOneWidget);
      expect(find.text('Sides'), findsOneWidget);
      expect(find.text('Paper size'), findsOneWidget);
      expect(find.text('Tray'), findsOneWidget);
      expect(find.text('Quality'), findsOneWidget);
      expect(find.text('Pages'), findsOneWidget);
    });

    testWidgets('shows only what a simpler printer offers', (tester) async {
      backend
        ..printerList = [
          {
            ...printerBody(),
            'capabilities': {
              ...printerBody()['capabilities']! as Map<String, Object?>,
              'print': {
                'supported': true,
                'color': false,
                'collation': false,
                'secure_print': false,
                'duplex_modes': ['one_sided'],
                'document_formats': ['application/pdf'],
                'media_sizes': <String>[],
                'media_types': <String>[],
                'quality_modes': ['normal'],
                'resolutions_dpi': <int>[],
                'finishing': <String>[],
                'max_copies': 2,
                'trays': <Object>[],
              },
            },
          },
        ]
        ..renderer.pageCount = 1;
      await pump(tester);

      await chooseFile(tester);

      expect(find.text('1 page'), findsOneWidget);
      expect(find.text('Copies'), findsOneWidget);
      for (final absent in [
        'Colour',
        'Sides',
        'Paper size',
        'Tray',
        'Quality',
        'Pages',
      ]) {
        expect(find.text(absent), findsNothing, reason: absent);
      }
      // No more copies than the printer makes.
      await tester.tap(find.byTooltip('+'));
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
      expect(
        tester.widget<IconButton>(find.byType(IconButton).last).onPressed,
        isNull,
      );
    });

    testWidgets('prints the way that was chosen', (tester) async {
      await pump(tester);
      await chooseFile(tester);

      for (final button in ['+', '+', '−']) {
        await tester.tap(find.byTooltip(button));
        await tester.pump();
      }
      await tester.tap(find.byType(Switch));
      await tester.pump();
      Future<void> pick(String field, String option) async {
        await press(tester, field);
        await tester.pumpAndSettle();
        await tester.tap(find.text(option).last);
        await tester.pumpAndSettle();
      }

      await pick('One side', 'Both sides');
      await pick('Let the printer choose', 'A4');
      await tester.ensureVisible(find.text('Pages'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Pages'),
        '1, 2',
      );
      await startPrinting(tester);

      expect(find.text('Printed'), findsOneWidget);
      final settings = backend.jobList.single['settings']! as Map;
      expect(settings['copies'], 2);
      final sent = backend.printed.single.message.group(IppGroupTag.job)!;
      expect(sent['copies']!.first, 2);
      expect(sent['sides']!.first, 'two-sided-long-edge');
      expect(sent['media']!.first, 'iso_a4_210x297mm');
      expect(sent['page-ranges']!.values.map((v) => '${v.value}'), [
        '1-1',
        '2-2',
      ]);

      await tester.tap(find.text('Done'));
      verify(router.pop).called(1);
    });

    testWidgets('sets a tray and a quality, and back to the printer’s own', (
      tester,
    ) async {
      await pump(tester);
      await chooseFile(tester);
      Future<void> pick(Finder field, String option) async {
        await tester.ensureVisible(field);
        await tester.pump();
        await tester.tap(field);
        await tester.pumpAndSettle();
        await tester.tap(find.text(option).last);
        await tester.pumpAndSettle();
      }

      final fields = find.byWidgetPredicate(
        (widget) => widget is DropdownButtonFormField<String?>,
      );
      await pick(fields.at(2), 'Tray 1');
      await pick(fields.at(3), 'Best');
      await pick(fields.at(3), 'Let the printer choose');
      await tester.enterText(find.widgetWithText(TextFormField, 'Pages'), '');
      await tester.pump();

      final choices = tester
          .element(find.byType(PrintOptions))
          .read<PrintCubit>()
          .state
          .choices;
      expect(choices.tray, 'tray-1');
      expect(choices.quality, isNull);
      expect(choices.pageRanges, isNull);
    });

    testWidgets('does not print pages it cannot make sense of', (tester) async {
      await pump(tester);
      await chooseFile(tester);
      await tester.ensureVisible(find.text('Pages'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Pages'),
        'the first few',
      );

      await startPrinting(tester);

      expect(find.textContaining('page numbers and ranges'), findsOneWidget);
      expect(backend.printed, isEmpty);
    });

    testWidgets('chooses another file from the document', (tester) async {
      await pump(tester);
      await chooseFile(tester);
      backend.picker.next = pickedPdf(name: 'Photo.jpg');

      await tester.tap(find.text('Choose another file'));
      await tester.pumpAndSettle();

      expect(find.text('Photo.jpg'), findsOneWidget);
    });

    testWidgets('says why the backend will not record the print', (
      tester,
    ) async {
      backend.fail(
        'POST /organizations/$_org/jobs',
        403,
        'permission.denied',
        detail: 'You cannot print here.',
      );
      await pump(tester);
      await chooseFile(tester);

      await startPrinting(tester);

      expect(find.text('You cannot print here.'), findsOneWidget);
      expect(backend.printed, isEmpty);
    });

    testWidgets('shows where a print has got to, and cancels it', (
      tester,
    ) async {
      backend.printerJobState = 5;
      await pump(tester);
      await chooseFile(tester);

      await startPrinting(tester, ends: false);

      expect(find.text('Printing…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Leaving would abandon it: it is cancelled or finished.
      final leaving = tester.widget<PopScope<dynamic>>(
        find
            .descendant(
              of: find.byType(PrintView),
              matching: find.byWidgetPredicate((widget) => widget is PopScope),
            )
            .first,
      );
      expect(leaving.canPop, isFalse);

      await tester.tap(find.text('Cancel printing'));
      await tester.pumpAndSettle();

      expect(find.text('Cancelled'), findsOneWidget);
      expect(backend.jobList.single['status'], 'cancelled');
    });

    testWidgets('says what the printer has stopped for', (tester) async {
      backend.printerJobState = 6;
      await pump(tester);
      await chooseFile(tester);

      await startPrinting(tester, ends: false);

      expect(find.text('The printer has stopped'), findsOneWidget);
      expect(find.text('Out of paper'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Someone loads paper.
      backend.printerJobState = 9;
      await tester.pumpAndSettle();
      expect(find.text('Printed'), findsOneWidget);
    });

    testWidgets('says when another connection had to be used', (tester) async {
      backend
        ..printerList = [
          printerBody(
            connections: [
              connectionBody(type: 'ipps', port: 443),
              connectionBody(priority: 2),
            ],
          ),
        ]
        ..printerJobState = 5;
      interfere((request, _) => request.uri.scheme == 'https');
      await pump(tester);
      await chooseFile(tester);

      await startPrinting(tester, ends: false);

      expect(find.textContaining('another is being used'), findsOneWidget);
      await tester.tap(find.text('Cancel printing'));
      await tester.pumpAndSettle();
    });

    testWidgets('says why a print failed, and goes back to try again', (
      tester,
    ) async {
      backend.unplugPrinter();
      await pump(tester);
      await chooseFile(tester);

      await startPrinting(tester);

      expect(find.text('Not printed'), findsOneWidget);
      expect(find.textContaining('did not answer'), findsOneWidget);
      expect(find.text("Use your phone's print dialog"), findsNothing);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('How to print it'), findsOneWidget);
    });

    testWidgets('offers the phone’s print dialog when the printer cannot', (
      tester,
    ) async {
      backend.plugInPrinter(formats: const ['application/postscript']);
      await pump(tester);
      await chooseFile(tester);
      await startPrinting(tester);
      expect(find.textContaining('cannot take this document'), findsOneWidget);

      await tester.tap(find.text("Use your phone's print dialog"));
      await tester.pumpAndSettle();

      expect(find.text("Sent to your phone's print dialog"), findsOneWidget);
      expect(backend.renderer.systemPrinted, hasLength(1));
      expect(find.text('Print again'), findsOneWidget);
    });

    testWidgets('says to check the printer when it cannot tell what happened', (
      tester,
    ) async {
      interfere(
        (_, operation) =>
            operation == IppOperation.printJob ||
            operation == IppOperation.getJobs,
      );
      await pump(tester);
      await chooseFile(tester);

      await startPrinting(tester);

      expect(find.text('Check the printer'), findsOneWidget);
      expect(find.textContaining('printed twice'), findsOneWidget);
      expect(backend.jobList.single['error_code'], 'print.outcome_unknown');
    });

    testWidgets('leaves a job with a printer that has gone quiet', (
      tester,
    ) async {
      backend.printerJobState = 5;
      interfere((_, operation) => operation == IppOperation.getJobAttributes);
      await pump(tester);
      await chooseFile(tester);

      await startPrinting(tester);

      expect(find.text('Still printing'), findsOneWidget);
      expect(find.text('Print again'), findsOneWidget);
    });
    group('saved settings', () {
      Text copies(WidgetTester tester) => tester.widget<Text>(
        find.descendant(
          of: find.byType(PrintOptions),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Text && int.tryParse(widget.data ?? '') != null,
          ),
        ),
      );

      final nameField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );

      Future<void> open(WidgetTester tester) async {
        await pump(tester);
        await chooseFile(tester);
      }

      Future<void> manage(WidgetTester tester, String preset) async {
        await press(tester, 'Manage');
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.widgetWithText(ListTile, preset),
            matching: find.byTooltip('Show menu'),
          ),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('offers to save the choices, with none saved yet', (
        tester,
      ) async {
        await open(tester);

        expect(find.text('Save these settings'), findsOneWidget);
        expect(find.byType(ActionChip), findsNothing);
        expect(find.text('Manage'), findsNothing);
      });

      testWidgets('starts from the settings marked for it', (tester) async {
        backend.presetList = [presetBody(isDefault: true, copies: 2)];

        await open(tester);

        expect(copies(tester).data, '2');
        expect(find.text('Both sides'), findsOneWidget);
      });

      testWidgets('uses saved settings when they are tapped', (tester) async {
        backend.presetList = [
          presetBody(copies: 4, tray: 'tray-1'),
          presetBody(id: 'preset-2', name: 'Letterhead', copies: 6),
        ];
        await open(tester);
        expect(copies(tester).data, '1');

        await press(tester, 'Handouts');
        await tester.pumpAndSettle();

        expect(copies(tester).data, '4');
        expect(find.text('Tray 1'), findsOneWidget);
      });

      testWidgets('says when saved settings have since been deleted', (
        tester,
      ) async {
        backend.presetList = [presetBody()];
        await open(tester);
        backend.presetList = [];

        await press(tester, 'Handouts');
        await tester.pumpAndSettle();

        expect(find.text('Those settings are no longer saved.'), findsOne);
        expect(find.byType(ActionChip), findsNothing);
      });

      testWidgets('saves the choices under a name', (tester) async {
        await open(tester);
        await tester.tap(find.byTooltip('+'));
        await tester.pump();

        await press(tester, 'Save these settings');
        await tester.pumpAndSettle();
        // Nothing to save under until there is a name.
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
              .onPressed,
          isNull,
        );
        await tester.enterText(nameField, ' Two up ');
        await tester.pump();
        await tester.tap(find.textContaining('Start every print'));
        await tester.tap(find.text('Share with the workspace'));
        await tester.pump();
        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await tester.pumpAndSettle();

        final saved = backend.presetList.single;
        expect(saved['name'], 'Two up');
        expect(saved['is_default'], isTrue);
        expect(saved['scope'], 'organization');
        expect(saved['printer_id'], 'printer-1');
        expect((saved['settings']! as Map)['copies'], 2);
        expect(find.widgetWithText(ActionChip, 'Two up'), findsOneWidget);
        expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      });

      testWidgets('saves nothing when the dialog is closed', (tester) async {
        await open(tester);

        await press(tester, 'Save these settings');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(backend.presetList, isEmpty);
      });

      testWidgets('says why settings could not be saved', (tester) async {
        backend.fail(
          'POST /organizations/$_org/presets',
          403,
          'permission.denied',
          detail: 'Your role does not allow this action.',
        );
        await open(tester);

        await press(tester, 'Save these settings');
        await tester.pumpAndSettle();
        await tester.enterText(nameField, 'Mine');
        await tester.pump();
        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await tester.pumpAndSettle();

        expect(find.text('Your role does not allow this action.'), findsOne);
      });

      testWidgets('renames saved settings', (tester) async {
        backend.presetList = [presetBody()];
        await open(tester);

        await manage(tester, 'Handouts');
        await tester.tap(find.text('Rename'));
        await tester.pumpAndSettle();
        // Only the name is asked for.
        expect(find.textContaining('Start every print'), findsNothing);
        await tester.enterText(nameField, 'Minutes');
        await tester.pump();
        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await tester.pumpAndSettle();

        expect(backend.presetList.single['name'], 'Minutes');
        expect(find.widgetWithText(ListTile, 'Minutes'), findsOneWidget);
      });

      testWidgets('leaves the name alone when renaming is given up', (
        tester,
      ) async {
        backend.presetList = [presetBody()];
        await open(tester);

        await manage(tester, 'Handouts');
        await tester.tap(find.text('Rename'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(backend.presetList.single['name'], 'Handouts');
      });

      testWidgets('marks settings to start from, and unmarks them', (
        tester,
      ) async {
        backend.presetList = [
          presetBody(),
          presetBody(
            id: 'preset-2',
            name: 'Letterhead',
            scope: 'organization',
            isDefault: true,
          ),
        ];
        await open(tester);

        await manage(tester, 'Handouts');
        await tester.tap(find.text('Start every print with this'));
        await tester.pumpAndSettle();

        expect(backend.presetList.first['is_default'], isTrue);
        expect(find.text('Every print starts with this'), findsOneWidget);
        expect(find.text('Shared with your workspace'), findsOneWidget);

        await tester.tap(
          find.descendant(
            of: find.widgetWithText(ListTile, 'Handouts'),
            matching: find.byTooltip('Show menu'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Stop starting with this'));
        await tester.pumpAndSettle();

        expect(backend.presetList.first['is_default'], isFalse);
      });

      testWidgets('says what a shared preset that prints start with is', (
        tester,
      ) async {
        backend.presetList = [
          presetBody(scope: 'organization', isDefault: true),
        ];
        await open(tester);

        await press(tester, 'Manage');
        await tester.pumpAndSettle();

        expect(
          find.text('Shared with your workspace\nEvery print starts with this'),
          findsOneWidget,
        );
      });

      testWidgets('replaces saved settings with the ones chosen now', (
        tester,
      ) async {
        backend.presetList = [presetBody(duplex: 'one_sided')];
        await open(tester);
        await tester.tap(find.byTooltip('+'));
        await tester.pump();
        await tester.tap(find.byTooltip('+'));
        await tester.pump();

        await manage(tester, 'Handouts');
        await tester.tap(find.text('Replace with the settings chosen now'));
        await tester.pumpAndSettle();

        expect((backend.presetList.single['settings']! as Map)['copies'], 3);
      });

      testWidgets('deletes saved settings', (tester) async {
        backend.presetList = [presetBody()];
        await open(tester);

        await manage(tester, 'Handouts');
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(backend.presetList, isEmpty);
        expect(find.widgetWithText(ListTile, 'Handouts'), findsNothing);
      });

      testWidgets('says in the list why a change could not be made', (
        tester,
      ) async {
        backend
          ..presetList = [presetBody()]
          ..fail(
            'DELETE /organizations/$_org/presets/preset-1',
            403,
            'permission.denied',
            detail: 'Your role does not allow this action.',
          );
        await open(tester);

        await manage(tester, 'Handouts');
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(
          find.text('Your role does not allow this action.'),
          findsWidgets,
        );
        expect(find.widgetWithText(ListTile, 'Handouts'), findsOneWidget);
      });

      testWidgets('lets someone who is not an admin change only their own', (
        tester,
      ) async {
        backend
          ..workspaces = [organizationBody(role: 'user')]
          ..presetList = [
            presetBody(),
            presetBody(
              id: 'preset-2',
              name: 'Letterhead',
              scope: 'organization',
            ),
          ];
        await tester.runAsync(backend.organizations.list);
        await open(tester);

        await press(tester, 'Save these settings');
        await tester.pumpAndSettle();
        expect(find.text('Share with the workspace'), findsNothing);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        await press(tester, 'Manage');
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.widgetWithText(ListTile, 'Handouts'),
            matching: find.byTooltip('Show menu'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.widgetWithText(ListTile, 'Letterhead'),
            matching: find.byTooltip('Show menu'),
          ),
          findsNothing,
        );
      });
    });
  });
}

/// A renderer whose preview arrives when the test says.
class _SlowRenderer extends FakePageRenderer {
  new(this._preview);

  final Future<DocumentPreview> _preview;

  @override
  Future<DocumentPreview> preview(PickedDocument document) => _preview;
}
