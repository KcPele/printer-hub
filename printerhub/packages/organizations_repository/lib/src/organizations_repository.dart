import 'dart:convert';

import 'package:api_client/api_client.dart';
import 'package:local_store/local_store.dart';
import 'package:organizations_repository/src/organization.dart';
import 'package:organizations_repository/src/team.dart';

/// The workspaces a person belongs to: listing and creating them, their
/// rules, their members, and their invitations.
///
/// The list is kept on the device, so the app knows its workspace when it
/// starts offline.
class OrganizationsRepository {
  new({required this._client, required this._store});

  static const String _cacheKey = 'organizations.list';

  final PrinterHubClient _client;
  final SecureStore _store;

  /// The workspaces the user belongs to.
  ///
  /// When the API cannot be reached, answers with the list from the last
  /// time it could. Throws an [ApiException] when there is no such list, or
  /// when the API refuses.
  Future<List<Organization>> list() async {
    try {
      final organizations = await apiCall(
        () => _client.api.organizations.listOrganizations(),
      );
      final list = organizations.map(Organization.fromApi).toList();
      await _keep(list);
      return list;
    } on ApiUnreachable {
      final kept = await this.kept();
      if (kept == null) rethrow;
      return kept;
    }
  }

  /// Creates a workspace owned by the user.
  Future<Organization> create(String name) async {
    final created = Organization.fromApi(
      await apiCall(
        () => _client.api.organizations.createOrganization(
          body: OrganizationCreate(name: name),
        ),
      ),
    );
    await _keep([...?await kept(), created]);
    return created;
  }

  /// Forgets the kept list. Call when the user signs out.
  Future<void> clear() => _store.delete(_cacheKey);

  Future<void> _keep(List<Organization> organizations) {
    return _store.write(
      _cacheKey,
      jsonEncode([for (final item in organizations) item.toJson()]),
    );
  }

  /// The list from the last time the API was reached, without using the
  /// network. Null when there is none.
  Future<List<Organization>?> kept() async {
    final json = await _store.read(_cacheKey);
    if (json == null) return null;
    try {
      return [
        for (final item in jsonDecode(json) as List<dynamic>)
          Organization.fromJson(item as Map<String, dynamic>),
      ];
    } on Object {
      // Written by an older version of the app.
      return null;
    }
  }

  /// One workspace with its rules, as the API has it now.
  Future<Workspace> details(String organizationId) async {
    return Workspace.fromApi(
      await apiCall(
        () => _client.api.organizations.getOrganization(orgId: organizationId),
      ),
    );
  }

  /// Renames a workspace, changes its rules, or both. What is left null
  /// stays as it is. The kept list learns the new name.
  Future<Workspace> update(
    String organizationId, {
    String? name,
    WorkspacePolicy? policy,
  }) async {
    final updated = Workspace.fromApi(
      await apiCall(
        () => _client.api.organizations.updateOrganization(
          orgId: organizationId,
          body: OrganizationUpdate(name: name, settings: policy?.toApi()),
        ),
      ),
    );
    await _keep([
      for (final kept in await this.kept() ?? <Organization>[])
        if (kept.id == organizationId) updated.organization else kept,
    ]);
    return updated;
  }

  /// Deletes a workspace, for everyone in it. Only its owner may.
  Future<void> delete(String organizationId) async {
    await apiCall(
      () => _client.api.organizations.deleteOrganization(orgId: organizationId),
    );
    await _forget(organizationId);
  }

  Future<void> _forget(String organizationId) async {
    await _keep([
      for (final kept in await this.kept() ?? <Organization>[])
        if (kept.id != organizationId) kept,
    ]);
  }

  /// The people in a workspace.
  Future<List<Member>> members(String organizationId) async {
    final members = await apiCall(
      () => _client.api.organizations.listMembers(orgId: organizationId),
    );
    return members.map(Member.fromApi).toList();
  }

  Future<Member> changeRole({
    required String organizationId,
    required String userId,
    required String role,
  }) async {
    return Member.fromApi(
      await apiCall(
        () => _client.api.organizations.changeMemberRole(
          orgId: organizationId,
          userId: userId,
          body: MemberUpdate(role: Role.fromJson(role)),
        ),
      ),
    );
  }

  /// Takes someone out of a workspace.
  Future<void> removeMember({
    required String organizationId,
    required String userId,
  }) {
    return apiCall(
      () => _client.api.organizations.removeMember(
        orgId: organizationId,
        userId: userId,
      ),
    );
  }

  /// Takes the signed-in person, whose id is [userId], out of a workspace.
  Future<void> leave({
    required String organizationId,
    required String userId,
  }) async {
    await removeMember(organizationId: organizationId, userId: userId);
    await _forget(organizationId);
  }

  /// Invites someone by email. The invitation comes back with the code
  /// they join with, which the API shows this once.
  Future<Invitation> invite({
    required String organizationId,
    required String email,
    String role = 'user',
  }) async {
    final created = await apiCall(
      () => _client.api.organizations.createInvitation(
        orgId: organizationId,
        body: InvitationCreate(email: email, role: Role.fromJson(role)),
      ),
    );
    return Invitation(
      id: created.id,
      email: created.email,
      role: created.role.json ?? role,
      expiresAt: created.expiresAt,
      code: created.token,
    );
  }

  /// The invitations a workspace has sent that nobody has taken up yet.
  Future<List<Invitation>> invitations(String organizationId) async {
    final invitations = await apiCall(
      () => _client.api.organizations.listInvitations(orgId: organizationId),
    );
    return [
      for (final invitation in invitations)
        Invitation(
          id: invitation.id,
          email: invitation.email,
          role: invitation.role.json ?? 'viewer',
          expiresAt: invitation.expiresAt,
        ),
    ];
  }

  Future<void> revokeInvitation({
    required String organizationId,
    required String invitationId,
  }) {
    return apiCall(
      () => _client.api.organizations.revokeInvitation(
        orgId: organizationId,
        invitationId: invitationId,
      ),
    );
  }

  /// The invitations sent to the signed-in person's email address.
  Future<List<ReceivedInvitation>> received() async {
    final invitations = await apiCall(
      _client.api.organizations.listMyInvitations,
    );
    return invitations.map(ReceivedInvitation.fromApi).toList();
  }

  /// Joins the workspace an invitation is to. The kept list gains it.
  Future<Organization> accept(String invitationId) {
    return _joined(
      () => _client.api.organizations.acceptMyInvitation(
        invitationId: invitationId,
      ),
    );
  }

  /// Joins a workspace with the code from an invitation.
  Future<Organization> acceptCode(String code) {
    return _joined(
      () => _client.api.organizations.acceptInvitation(
        body: InvitationAccept(token: code),
      ),
    );
  }

  Future<Organization> _joined(
    Future<OrganizationRead> Function() accept,
  ) async {
    final joined = Organization.fromApi(await apiCall(accept));
    await _keep([
      for (final kept in await this.kept() ?? <Organization>[])
        if (kept.id != joined.id) kept,
      joined,
    ]);
    return joined;
  }

  /// A page of what was done in a workspace, newest first. Pass [cursor]
  /// from the page before to read on.
  Future<({List<LoggedAction> actions, String? next})> log(
    String organizationId, {
    String? cursor,
  }) async {
    final page = await apiCall(
      () => _client.api.audit.listAuditLogs(
        orgId: organizationId,
        cursor: cursor,
      ),
    );
    return (
      actions: page.items.map(LoggedAction.fromApi).toList(),
      next: page.nextCursor,
    );
  }

  /// What is switched on for a workspace, by name. Something not named is
  /// off.
  Future<Map<String, bool>> features(String organizationId) async {
    final resolved = await apiCall(
      () => _client.api.featureFlags.getFeatureFlags(orgId: organizationId),
    );
    return resolved.flags;
  }
}
