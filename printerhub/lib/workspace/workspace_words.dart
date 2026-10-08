import 'package:organizations_repository/organizations_repository.dart';
import 'package:printerhub/l10n/l10n.dart';

/// The words the app uses for a workspace: the roles people have in it and
/// what its log says was done.
abstract final class WorkspaceWords {
  /// The roles someone can be given, the most trusted first. Owner is not
  /// among them: a workspace's owner is not chosen from a list.
  static const List<String> assignable = [
    'admin',
    'operator',
    'user',
    'viewer',
  ];

  static String role(AppLocalizations l10n, String role) {
    return switch (role) {
      'owner' => l10n.roleOwner,
      'admin' => l10n.roleAdmin,
      'operator' => l10n.roleOperator,
      'viewer' => l10n.roleViewer,
      _ => l10n.roleUser,
    };
  }

  /// What a logged action was, in a few words.
  static String action(AppLocalizations l10n, LoggedAction logged) {
    return switch (logged.action) {
      'printer.added' => l10n.logActionPrinterAdded,
      'printer.updated' => l10n.logActionPrinterUpdated,
      'printer.removed' => l10n.logActionPrinterRemoved,
      'pairing_token.created' => l10n.logActionPrinterShared,
      'connection.created' => l10n.logActionConnectionCreated,
      'connection.modified' ||
      'connection.priority_changed' => l10n.logActionConnectionChanged,
      'connection.removed' => l10n.logActionConnectionRemoved,
      'connection.credentials_accessed' => l10n.logActionCredentialsRead,
      'connection.credentials_changed' => l10n.logActionCredentialsChanged,
      'invitation.created' => l10n.logActionInvitationCreated,
      'invitation.revoked' => l10n.logActionInvitationRevoked,
      'member.joined' => l10n.logActionMemberJoined,
      'member.left' => l10n.logActionMemberLeft,
      'member.role_changed' => l10n.logActionMemberRoleChanged,
      'member.account_deleted' => l10n.logActionMemberAccountDeleted,
      'organization.created' => l10n.logActionOrganizationCreated,
      'organization.updated' => l10n.logActionOrganizationUpdated,
      // One the app has no words for yet is shown as the log names it.
      final other => _plain(other),
    };
  }

  /// `user.logged_in` as `User logged in`.
  static String _plain(String action) {
    final words = action.replaceAll(RegExp('[._]'), ' ').trim();
    return words.isEmpty
        ? action
        : '${words[0].toUpperCase()}${words.substring(1)}';
  }

  /// Who or what a logged action concerned, when the log says: the address
  /// an invitation went to, the name of a printer.
  static String? about(LoggedAction logged) {
    for (final key in const ['email', 'name', 'friendly_name']) {
      final value = logged.detail[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }
}
