import 'dart:io';

import 'package:api_client/testing.dart';
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
    backend.picker.pictures = [
      pickedPicture(backend.scans, name: 'One.jpg'),
      pickedPicture(backend.scans, name: 'Two.jpg'),
    ];
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

  Future<void> pump(WidgetTester tester, {bool withPrinter = true}) async {
    if (withPrinter) {
      final listed = await tester.runAsync(() => backend.printers.list(_org));
      printers.emit(
        PrintersState(status: PrintersStatus.ready, printers: listed!),
      );
    }
    await tester.pumpApp(
      const PhotoSheetPage(),
      backend: backend,
      printersCubit: printers,
      router: router,
    );
    await tester.pumpAndSettle();
  }

  /// Lets the files, which take real time, be read and written.
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
  }

  Future<void> choosePhotos(WidgetTester tester) async {
    await press(tester, find.text('Choose photos'));
    await until(tester, () => find.text('One.jpg').evaluate().isNotEmpty);
  }

  testWidgets('chooses photos, lays them out, and prints the sheet', (
    tester,
  ) async {
    await pump(tester);
    expect(find.textContaining("paper's true size"), findsOneWidget);
    expect(find.text('Layout'), findsNothing);

    await choosePhotos(tester);
    expect(find.text('Two.jpg'), findsOneWidget);
    await tester.tap(find.byTooltip('Take this photo out').last);
    await tester.pumpAndSettle();
    expect(find.text('Two.jpg'), findsNothing);

    await press(tester, find.text('One to a page'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Passport photos (35 × 45 mm)').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('25 copies of each photo'), findsOneWidget);

    await press(tester, find.text('A4'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4 × 6 in').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('4 copies of each photo'), findsOneWidget);

    await press(tester, find.widgetWithText(FilledButton, 'Make the sheet'));
    await until(
      tester,
      () => find.text('Your photos are ready').evaluate().isNotEmpty,
    );
    expect(find.text('Your photos are ready'), findsOneWidget);
    expect(find.text('Make it again'), findsOneWidget);

    await press(tester, find.widgetWithText(FilledButton, 'Print it'));
    await tester.pumpAndSettle();
    final pushed = verify(
      () => router.push<Object?>(
        AppRoutes.printOn('printer-1'),
        extra: captureAny(named: 'extra'),
      ),
    )..called(1);
    expect(pushed.captured.single, isA<PickedDocument>());

    await press(tester, find.widgetWithText(OutlinedButton, 'Share'));
    await tester.pump();
    expect(backend.sharer.shared, hasLength(1));
  });

  testWidgets('adds more photos to the ones chosen', (tester) async {
    await pump(tester);
    await choosePhotos(tester);

    backend.picker.pictures = [pickedPicture(backend.scans, name: 'Three.jpg')];
    await press(tester, find.text('Add more photos'));
    await until(tester, () => find.text('Three.jpg').evaluate().isNotEmpty);

    expect(find.text('One.jpg'), findsOneWidget);
    expect(find.text('Three.jpg'), findsOneWidget);
  });

  testWidgets('offers sharing only, where there is no printer to print on', (
    tester,
  ) async {
    await pump(tester, withPrinter: false);
    await choosePhotos(tester);

    await press(tester, find.widgetWithText(FilledButton, 'Make the sheet'));
    await until(
      tester,
      () => find.text('Your photos are ready').evaluate().isNotEmpty,
    );

    expect(find.widgetWithText(FilledButton, 'Print it'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Share'), findsOneWidget);
  });

  testWidgets('prints nothing when no printer is picked', (tester) async {
    backend.printerList = [
      printerBody(),
      printerBody(id: 'printer-2', name: 'Back office'),
    ];
    await pump(tester);
    await choosePhotos(tester);
    await press(tester, find.widgetWithText(FilledButton, 'Make the sheet'));
    await until(
      tester,
      () => find.text('Your photos are ready').evaluate().isNotEmpty,
    );

    await press(tester, find.widgetWithText(FilledButton, 'Print it'));
    await tester.pumpAndSettle();
    expect(find.text('Which printer?'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    verifyNever(() => router.push<Object?>(any(), extra: any(named: 'extra')));
  });

  testWidgets('says when a photo cannot be read', (tester) async {
    await pump(tester);
    await choosePhotos(tester);
    for (final photo in backend.picker.pictures) {
      await tester.runAsync(
        () => File(photo.path).writeAsBytes([1, 2, 3], flush: true),
      );
    }

    await press(tester, find.widgetWithText(FilledButton, 'Make the sheet'));
    await until(
      tester,
      () => find.textContaining('could not be read').evaluate().isNotEmpty,
    );

    expect(find.textContaining('could not be read'), findsOneWidget);
  });
}
