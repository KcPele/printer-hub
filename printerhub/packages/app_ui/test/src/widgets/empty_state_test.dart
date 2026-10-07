import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group('EmptyState', () {
    testWidgets('shows the picture, the title, and the message', (
      tester,
    ) async {
      await tester.pumpThemed(
        const EmptyState(
          illustration: AppIllustrations.printer,
          title: 'No printers yet',
          message: 'Printers you add appear here.',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppIllustration), findsOneWidget);
      expect(find.text('No printers yet'), findsOneWidget);
      expect(find.text('Printers you add appear here.'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('shows the next thing to do when given one', (tester) async {
      var taps = 0;
      await tester.pumpThemed(
        EmptyState(
          illustration: AppIllustrations.printer,
          title: 'No printers yet',
          message: 'Printers you add appear here.',
          action: FilledButton(
            onPressed: () => taps++,
            child: const Text('Add a printer'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add a printer'));

      expect(taps, 1);
    });
  });
}
