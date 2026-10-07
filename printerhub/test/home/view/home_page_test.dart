import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/home/home.dart';

import '../../helpers/helpers.dart';

void main() {
  group('HomePage', () {
    testWidgets('tells a new user what the app is for and how to begin', (
      tester,
    ) async {
      await tester.pumpApp(const HomePage());
      await tester.pumpAndSettle();

      expect(find.text('PrinterHub'), findsOneWidget);
      expect(find.byType(AppIllustration), findsOneWidget);
      expect(find.text('Find a printer, tap it, use it'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Follow every job'), 200);
      expect(find.text('Getting started'), findsOneWidget);
      expect(find.text('Add a printer'), findsOneWidget);
      expect(find.text('Print or scan'), findsOneWidget);
      for (final number in ['1', '2', '3']) {
        expect(find.text(number), findsOneWidget);
      }
    });
  });
}
