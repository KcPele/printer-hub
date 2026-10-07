import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppSubmitButton', () {
    testWidgets('shows its label and can be pressed', (tester) async {
      var presses = 0;
      await tester.pumpThemed(
        AppSubmitButton(label: 'Sign in', onPressed: () => presses++),
      );

      await tester.tap(find.text('Sign in'));

      expect(presses, 1);
    });

    testWidgets('shows progress and ignores presses while loading', (
      tester,
    ) async {
      var presses = 0;
      await tester.pumpThemed(
        AppSubmitButton(
          label: 'Sign in',
          loading: true,
          onPressed: () => presses++,
        ),
      );

      await tester.tap(find.byType(FilledButton), warnIfMissed: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
      expect(presses, 0);
    });
  });
}
