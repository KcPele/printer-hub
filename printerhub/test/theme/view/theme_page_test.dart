import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/theme/theme.dart';

import '../../helpers/helpers.dart';

void main() {
  group('ThemePage', () {
    testWidgets('explains the choice and shows the picker', (tester) async {
      await tester.pumpApp(const ThemePage());

      expect(find.text('Theme'), findsOneWidget);
      expect(
        find.text('Choose how PrinterHub looks. It changes straight away.'),
        findsOneWidget,
      );
      expect(find.byType(ThemePicker), findsOneWidget);
    });
  });
}
