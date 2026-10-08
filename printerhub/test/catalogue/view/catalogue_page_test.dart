import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/catalogue/catalogue.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;
  late MockGoRouter router;

  setUp(() async {
    backend = TestBackend();
    router = recordingRouter();
    await backend.signedInBefore();
  });
  tearDown(() => backend.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpApp(
      const CataloguePage(),
      backend: backend,
      router: router,
    );
    await tester.pumpAndSettle();
  }

  group('CataloguePage', () {
    testWidgets('lists the families with what each is for', (tester) async {
      await pump(tester);

      expect(find.text('Xerox VersaLink C7100 Series'), findsOneWidget);
      expect(find.text('HP DeskJet, ENVY, and Smart Tank'), findsOneWidget);
      expect(find.text('Brother HL-L lasers'), findsOneWidget);
      expect(find.text('Compact laser printers for the desk.'), findsOneWidget);
    });

    testWidgets('lists a family that has no summary', (tester) async {
      backend.families = [
        {...backend.families.first, 'summary': null},
      ];

      await pump(tester);

      expect(find.text('Xerox VersaLink C7100 Series'), findsOneWidget);
    });

    testWidgets('narrows as a name is typed', (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'brother');
      await tester.pumpAndSettle();

      expect(find.text('Brother HL-L lasers'), findsOneWidget);
      expect(find.text('Xerox VersaLink C7100 Series'), findsNothing);
    });

    testWidgets('narrows to the printers people have at home', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.text('HP DeskJet, ENVY, and Smart Tank'), findsOneWidget);
      expect(find.text('Brother HL-L lasers'), findsNothing);

      await tester.tap(find.text('Office'));
      await tester.pumpAndSettle();
      expect(find.text('Brother HL-L lasers'), findsOneWidget);

      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('HP DeskJet, ENVY, and Smart Tank'), findsOneWidget);
    });

    testWidgets('says a printer that is not listed can still be added', (
      tester,
    ) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();

      expect(find.textContaining('You can still add your printer'), findsOne);
      await tester.tap(find.text('Add a printer'));
      verify(() => router.go(AppRoutes.addPrinter)).called(1);
    });

    testWidgets('shows what a family usually does and how to get it ready', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('Xerox VersaLink C7100 Series'));
      await tester.pumpAndSettle();

      expect(find.byType(FamilySheet), findsOneWidget);
      expect(find.text('What these printers usually do'), findsOneWidget);
      expect(find.text('Prints in colour'), findsOneWidget);
      expect(find.text('Scans from the glass and the feeder'), findsOneWidget);
      expect(find.text('Before you add it'), findsOneWidget);
      expect(find.text('1.'), findsOneWidget);
      expect(
        find.text('Connect the printer to the office network.'),
        findsOneWidget,
      );
      expect(find.textContaining('Models differ'), findsOneWidget);
    });

    testWidgets('shows a family with nothing to do first', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Brother HL-L lasers'));
      await tester.pumpAndSettle();

      expect(find.text('Prints in black and white'), findsOneWidget);
      expect(find.text('Before you add it'), findsNothing);
    });

    testWidgets('goes on to add the printer from a family', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Xerox VersaLink C7100 Series'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Add this printer'));
      await tester.tap(find.text('Add this printer'));
      await tester.pumpAndSettle();

      expect(find.byType(FamilySheet), findsNothing);
      verify(() => router.go(AppRoutes.addPrinter)).called(1);
    });

    testWidgets('says when the catalogue cannot be read, and tries again', (
      tester,
    ) async {
      backend.offline = true;
      await pump(tester);

      expect(find.text("Couldn't load the catalogue"), findsOneWidget);

      backend.offline = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Brother HL-L lasers'), findsOneWidget);
    });
  });
}
