import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/printers/printers.dart';

import '../../helpers/helpers.dart';

void main() {
  group('PrintersPage', () {
    testWidgets('explains what will appear when there are no printers', (
      tester,
    ) async {
      await tester.pumpApp(const PrintersPage());
      await tester.pumpAndSettle();

      expect(find.text('Printers'), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No printers yet'), findsOneWidget);
    });
  });
}
