import 'dart:ui';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppLogo', () {
    testWidgets('draws the mark at the size asked for', (tester) async {
      await tester.pumpThemed(const AppLogo(size: 64));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(AppLogo)), const Size(64, 64));
      expect(tester.takeException(), isNull);
    });

    testWidgets('is hidden from screen readers unless given a name', (
      tester,
    ) async {
      await tester.pumpThemed(const AppLogo());
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('PrinterHub'), findsNothing);

      await tester.pumpThemed(const AppLogo(semanticLabel: 'PrinterHub'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('PrinterHub'), findsOneWidget);
    });
  });
}
