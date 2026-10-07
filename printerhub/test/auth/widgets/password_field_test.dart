import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/auth/auth.dart';

import '../../helpers/helpers.dart';

void main() {
  group('PasswordField', () {
    Future<void> pump(
      WidgetTester tester, {
      bool isNew = false,
      VoidCallback? onSubmitted,
    }) {
      return tester.pumpApp(
        Scaffold(
          body: PasswordField(
            controller: TextEditingController(),
            label: 'Password',
            validator: (_) => null,
            isNew: isNew,
            onSubmitted: onSubmitted,
          ),
        ),
      );
    }

    EditableText editable(WidgetTester tester) {
      return tester.widget<EditableText>(find.byType(EditableText));
    }

    testWidgets('hides what is typed until asked to show it', (tester) async {
      await pump(tester);
      expect(editable(tester).obscureText, isTrue);

      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(editable(tester).obscureText, isFalse);

      await tester.tap(find.byTooltip('Hide password'));
      await tester.pump();
      expect(editable(tester).obscureText, isTrue);
    });

    testWidgets('tells password managers which kind of password it is', (
      tester,
    ) async {
      await pump(tester);
      expect(editable(tester).autofillHints, [AutofillHints.password]);

      await pump(tester, isNew: true);
      expect(editable(tester).autofillHints, [AutofillHints.newPassword]);
    });

    testWidgets('submits from the keyboard', (tester) async {
      var submitted = 0;
      await pump(tester, onSubmitted: () => submitted++);

      await tester.enterText(find.byType(TextFormField), 'secret');
      await tester.testTextInput.receiveAction(TextInputAction.done);

      expect(submitted, 1);
    });

    testWidgets('does nothing on the keyboard action without a handler', (
      tester,
    ) async {
      await pump(tester);

      await tester.testTextInput.receiveAction(TextInputAction.done);

      expect(tester.takeException(), isNull);
    });
  });
}
