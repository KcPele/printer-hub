import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppNotice', () {
    testWidgets('is drawn in the colours of its status', (tester) async {
      for (final status in AppStatus.values) {
        final tone = AppSemanticColors.light.status(status);
        await tester.pumpThemed(
          AppNotice(message: 'Something happened', status: status),
        );

        expect(
          tester.widget<Text>(find.text('Something happened')).style?.color,
          tone.foreground,
        );
        expect(tester.widget<Icon>(find.byType(Icon)).color, tone.foreground);
      }
    });

    testWidgets('is an error unless told otherwise', (tester) async {
      await tester.pumpThemed(const AppNotice(message: 'Wrong password'));

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('offers something to do about it', (tester) async {
      var taps = 0;
      await tester.pumpThemed(
        AppNotice(
          message: 'Verify your email',
          status: AppStatus.warning,
          action: TextButton(
            onPressed: () => taps++,
            child: const Text('Enter code'),
          ),
        ),
      );

      await tester.tap(find.text('Enter code'));

      expect(taps, 1);
    });
  });
}
