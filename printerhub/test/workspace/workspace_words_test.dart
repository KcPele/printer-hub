import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:organizations_repository/organizations_repository.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/workspace/workspace.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  LoggedAction logged(String action, {Map<String, Object?> detail = const {}}) {
    return LoggedAction.fromApi(
      AuditLogRead.fromJson(auditBody(action: action, detail: detail).cast()),
    );
  }

  test('every role has a name', () {
    expect(
      [
        for (final role in ['owner', 'admin', 'operator', 'user', 'viewer'])
          WorkspaceWords.role(l10n, role),
      ],
      ['Owner', 'Admin', 'Operator', 'Member', 'Viewer'],
    );
    expect(WorkspaceWords.assignable, isNot(contains('owner')));
  });

  test('every action the backend logs has words of its own', () {
    const actions = [
      'printer.added',
      'printer.updated',
      'printer.removed',
      'pairing_token.created',
      'connection.created',
      'connection.modified',
      'connection.removed',
      'connection.credentials_accessed',
      'connection.credentials_changed',
      'invitation.created',
      'invitation.revoked',
      'member.joined',
      'member.left',
      'member.role_changed',
      'member.account_deleted',
      'organization.created',
      'organization.updated',
    ];

    final words = {
      for (final action in actions) WorkspaceWords.action(l10n, logged(action)),
    };

    expect(words, hasLength(actions.length));
    expect(
      WorkspaceWords.action(l10n, logged('connection.priority_changed')),
      WorkspaceWords.action(l10n, logged('connection.modified')),
    );
    expect(words.any((word) => word.contains('.')), isFalse);
  });

  test('an action it has no words for is shown as the log names it', () {
    expect(
      WorkspaceWords.action(l10n, logged('user.logged_in')),
      'User logged in',
    );
    expect(WorkspaceWords.action(l10n, logged('.')), '.');
  });

  test('says who or what an action concerned, when the log does', () {
    expect(
      WorkspaceWords.about(
        logged('invitation.created', detail: {'email': 'grace@example.com'}),
      ),
      'grace@example.com',
    );
    expect(
      WorkspaceWords.about(
        logged('printer.added', detail: {'friendly_name': 'Front desk'}),
      ),
      'Front desk',
    );
    expect(
      WorkspaceWords.about(logged('printer.updated', detail: {'name': ''})),
      isNull,
    );
    expect(WorkspaceWords.about(logged('member.left')), isNull);
  });
}
