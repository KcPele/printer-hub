import 'package:api_client/testing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/workspace/workspace.dart';

import '../../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';

void main() {
  late TestBackend backend;

  setUp(() {
    backend = TestBackend()..invitationList = [invitationBody()];
  });
  tearDown(() => backend.close());

  Future<void> pump(WidgetTester tester, {String role = 'owner'}) async {
    backend.workspaces = [organizationBody(role: role)];
    await tester.runAsync(backend.signedInBefore);
    await tester.pumpApp(const MembersPage(), backend: backend);
    await tester.pumpAndSettle();
  }

  Future<void> menu(WidgetTester tester, String entry) async {
    await tester.tap(find.byTooltip('Show menu'));
    await tester.pumpAndSettle();
    // The entry's text sits inside the menu item that takes the tap.
    await tester.tap(find.text(entry).last, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  group('MembersPage', () {
    testWidgets('lists the people, and who is invited', (tester) async {
      await pump(tester);

      expect(find.text('Ada (You)'), findsOneWidget);
      expect(find.text('ada@example.com\nOwner'), findsOneWidget);
      expect(find.text('Grace Hopper'), findsOneWidget);
      expect(find.text('grace@example.com\nMember'), findsOneWidget);
      expect(find.text('Invited, not joined yet'), findsOneWidget);
      expect(find.textContaining('Member · until '), findsOneWidget);
      // Nobody changes themselves, or an owner, from here.
      expect(find.byTooltip('Show menu'), findsOneWidget);
    });

    testWidgets('only lists the people for an ordinary member', (tester) async {
      await pump(tester, role: 'user');

      expect(find.text('Grace Hopper'), findsOneWidget);
      expect(find.byTooltip('Show menu'), findsNothing);
      expect(find.text('Invited, not joined yet'), findsNothing);
      expect(find.text('Invite someone'), findsNothing);
    });

    testWidgets('gives someone another role', (tester) async {
      await pump(tester);

      await menu(tester, 'Admin');

      expect(find.text('grace@example.com\nAdmin'), findsOneWidget);
      expect(backend.memberList.last['role'], 'admin');
    });

    testWidgets('removes someone once that is confirmed', (tester) async {
      await pump(tester);

      await menu(tester, 'Remove from the workspace');
      expect(find.text('Remove Grace Hopper?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(backend.memberList, hasLength(2));

      await menu(tester, 'Remove from the workspace');
      await tester.tap(
        find.widgetWithText(TextButton, 'Remove from the workspace'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Grace Hopper'), findsNothing);
      expect(backend.memberList, hasLength(1));
    });

    testWidgets('takes an invitation back', (tester) async {
      await pump(tester);

      await tester.tap(find.byTooltip('Take back the invitation'));
      await tester.pumpAndSettle();

      expect(find.text('Invited, not joined yet'), findsNothing);
      expect(backend.invitationList, isEmpty);
    });

    testWidgets('invites someone, and shows the code to pass on', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await pump(tester);

      await tester.tap(find.text('Invite someone'));
      await tester.pumpAndSettle();
      // Not an address yet.
      await tester.enterText(find.byType(TextField), 'alan');
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Invite'))
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), 'alan@example.com');
      await tester.pump();
      await tester.tap(find.text('Member').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Operator').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Invite'));
      await tester.pumpAndSettle();

      expect(find.text('Invitation ready'), findsOneWidget);
      expect(find.textContaining('alan@example.com'), findsWidgets);
      expect(find.text('code-invitation-2'), findsOneWidget);
      expect(backend.invitationList.last['role'], 'operator');

      await tester.tap(find.text('Copy the code'));
      await tester.pumpAndSettle();
      expect(copied, 'code-invitation-2');
      expect(find.text('Copied'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Invitation ready'), findsNothing);
    });

    testWidgets('invites nobody when the dialog is closed', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Invite someone'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(backend.invitationList, hasLength(1));
    });

    testWidgets('says why a change could not be made', (tester) async {
      await pump(tester);
      backend.fail(
        'PATCH /organizations/$_org/members/user-2',
        409,
        'member.last_owner',
        detail: 'A workspace needs an owner.',
      );

      await menu(tester, 'Viewer');

      expect(find.text('A workspace needs an owner.'), findsOneWidget);
      expect(find.text('grace@example.com\nMember'), findsOneWidget);
    });

    testWidgets('says why the people cannot be read, and tries again', (
      tester,
    ) async {
      backend.workspaces = [organizationBody()];
      await tester.runAsync(backend.signedInBefore);
      backend.offline = true;
      await tester.pumpApp(const MembersPage(), backend: backend);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.text('The people could not be read'), findsOneWidget);

      backend.offline = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Grace Hopper'), findsOneWidget);
    });

    testWidgets('is empty for the moment there is no workspace', (
      tester,
    ) async {
      await tester.pumpApp(const MembersPage(), backend: backend);

      expect(find.byType(MembersView), findsNothing);
    });
  });
}
