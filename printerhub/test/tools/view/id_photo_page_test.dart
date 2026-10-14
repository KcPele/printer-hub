import 'dart:io';

import 'package:api_client/testing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/documents/documents.dart';
import 'package:printerhub/l10n/l10n.dart';
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
    final file = File('${backend.scans.path}/Me.jpg')
      ..writeAsBytesSync(img.encodeJpg(img.Image(width: 400, height: 300)));
    backend.picker.pictures = [PickedDocument.fromFile(file)];
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
      const IdPhotoPage(),
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

  IdPhotoCubit cubitOf(WidgetTester tester) =>
      BlocProvider.of(tester.element(find.byType(IdPhotoView)));

  testWidgets('frames a photo, makes the sheet, and prints it', (tester) async {
    await pump(tester);
    expect(find.textContaining('plain background'), findsOneWidget);
    expect(find.textContaining('own rules'), findsOneWidget);
    // Nothing to make before there is a photo.
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Create photo sheet'),
          )
          .onPressed,
      isNull,
    );

    await press(tester, find.text('Choose a photo'));
    await until(tester, () => cubitOf(tester).state.photo != null);
    expect(find.textContaining('fills the outline'), findsOneWidget);
    expect(find.text('Choose another photo'), findsOneWidget);

    // Moved within the frame, the part kept moves with it.
    final before = cubitOf(tester).state.frame;
    await tester.ensureVisible(find.byKey(const ValueKey('id-photo-frame')));
    await tester.pumpAndSettle();
    await tester.timedDrag(
      find.byKey(const ValueKey('id-photo-frame')),
      const Offset(-60, 0),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();

    final moved = cubitOf(tester).state.frame;
    expect(moved, isNot(before));
    expect(moved.left, greaterThan(before.left));

    await press(
      tester,
      find.widgetWithText(FilledButton, 'Create photo sheet'),
    );
    await tester.pump();
    await until(
      tester,
      () => find.text('Your ID photos are ready').evaluate().isNotEmpty,
    );
    expect(find.textContaining('25 photos on the sheet'), findsOneWidget);
    expect(find.byType(MadeFiles), findsOneWidget);
    expect(find.text('Create it again'), findsOneWidget);

    await press(tester, find.widgetWithText(FilledButton, 'Print it'));
    await tester.pumpAndSettle();
    final pushed = verify(
      () => router.push<Object?>(
        AppRoutes.printOn('printer-1'),
        extra: captureAny(named: 'extra'),
      ),
    )..called(1);
    expect(
      (pushed.captured.single as PickedDocument).name,
      startsWith('ID photos '),
    );

    await press(tester, find.widgetWithText(OutlinedButton, 'Share'));
    await tester.pump();
    expect(backend.sharer.shared, hasLength(1));
  });

  testWidgets('frames the photo afresh at another size and on another '
      'paper', (tester) async {
    await pump(tester, withPrinter: false);
    await press(tester, find.text('Choose a photo'));
    await until(tester, () => cubitOf(tester).state.photo != null);

    await press(tester, find.textContaining('35 × 45 mm'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('US passport').last);
    await tester.pumpAndSettle();
    expect(cubitOf(tester).state.size.key, '51x51');
    // A square frame takes the middle of a wide photo.
    expect(cubitOf(tester).state.frame.left, closeTo(0.125, 1e-9));

    await press(tester, find.text('A4'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Letter').last);
    await tester.pumpAndSettle();
    expect(cubitOf(tester).state.paper.name, 'na_letter_8.5x11in');

    // Every size has its words.
    for (final size in idPhotoSizes) {
      expect(
        idPhotoSizeName(
          await AppLocalizations.delegate.load(const Locale('en')),
          size,
        ),
        contains(' mm'),
      );
    }
  });

  testWidgets('frames a photo taller than the frame from its middle', (
    tester,
  ) async {
    final tall = File('${backend.scans.path}/Tall.jpg')
      ..writeAsBytesSync(img.encodeJpg(img.Image(width: 300, height: 600)));
    backend.picker.pictures = [PickedDocument.fromFile(tall)];
    await pump(tester, withPrinter: false);

    await press(tester, find.text('Choose a photo'));
    await until(tester, () => cubitOf(tester).state.photo != null);

    final frame = cubitOf(tester).state.frame;
    expect((frame.left, frame.right), (0, 1));
    expect(frame.top, greaterThan(0));
    expect(find.byKey(const ValueKey('id-photo-frame')), findsOneWidget);
  });

  testWidgets('says when a photo cannot be used', (tester) async {
    final words = File('${backend.scans.path}/Words.jpg')
      ..writeAsStringSync('not a picture');
    backend.picker.pictures = [PickedDocument.fromFile(words)];
    await pump(tester, withPrinter: false);

    await press(tester, find.text('Choose a photo'));
    await until(tester, () => cubitOf(tester).state.failure != null);

    expect(find.textContaining('could not be read'), findsOneWidget);
  });

  testWidgets('shows the ID photos made before, below', (tester) async {
    backend.documentList = [
      documentBody(name: 'ID photos Mon.pdf', source: 'id_photo'),
      documentBody(id: 'document-2', name: 'Scan.pdf'),
    ];
    await pump(tester, withPrinter: false);
    await until(
      tester,
      () => find.text('ID photos Mon.pdf').evaluate().isNotEmpty,
    );

    expect(find.text('Made here lately'), findsOneWidget);
    expect(find.text('Scan.pdf'), findsNothing);
  });
}
