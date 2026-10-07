import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/activity/activity.dart';

import '../../helpers/helpers.dart';

void main() {
  group('ActivityPage', () {
    testWidgets('explains what will appear when nothing has run', (
      tester,
    ) async {
      await tester.pumpApp(const ActivityPage());
      await tester.pumpAndSettle();

      expect(find.text('Activity'), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Nothing here yet'), findsOneWidget);
    });
  });
}
