import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group('StatusPill', () {
    testWidgets('uses the status colours, the same in every theme', (
      tester,
    ) async {
      for (final theme in AppTheme.all) {
        for (final status in AppStatus.values) {
          final tone = AppSemanticColors.light.status(status);
          await tester.pumpThemed(
            StatusPill(status: status, label: 'Ready'),
            theme: theme,
          );
          await tester.pumpAndSettle();

          expect(
            tester.widget<Text>(find.text('Ready')).style?.color,
            tone.foreground,
          );
          final fill = tester.widget<DecoratedBox>(
            find
                .descendant(
                  of: find.byType(StatusPill),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          expect((fill.decoration as BoxDecoration).color, tone.container);
        }
      }
    });

    testWidgets('shows a dot by default', (tester) async {
      await tester.pumpThemed(
        const StatusPill(status: AppStatus.success, label: 'Online'),
      );

      expect(find.byType(Icon), findsNothing);
      expect(
        find.descendant(
          of: find.byType(StatusPill),
          matching: find.byType(DecoratedBox),
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('shows an icon in place of the dot', (tester) async {
      await tester.pumpThemed(
        const StatusPill(
          status: AppStatus.error,
          label: 'Paper jam',
          icon: Icons.error_outline,
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.error_outline)).color,
        AppSemanticColors.light.error.foreground,
      );
    });
  });
}
