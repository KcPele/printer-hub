// Workspaces, members, and invitations against the real API, with nothing
// faked: the local backend (`make dev`).
//
//   make app-live-test
//
// Skipped when it is not running. It registers two throwaway accounts on
// the backend and deletes them at the end.
@Tags(['live'])
library;

import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_store/local_store.dart';
import 'package:organizations_repository/organizations_repository.dart';

Future<bool> _listening(int port) async {
  // Asked for by name: these tests make accounts on whatever is listening.
  if (Platform.environment['PRINTERHUB_LIVE'] != '1') return false;
  try {
    final socket = await Socket.connect(
      'localhost',
      port,
      timeout: const Duration(seconds: 1),
    );
    socket.destroy();
    return true;
  } on Object {
    return false;
  }
}

/// A new account on the backend, deleted when the test ends.
Future<({OrganizationsRepository workspaces, String userId, String email})>
_account(String name) async {
  final client = PrinterHubClient(
    baseUrl: Uri.parse('http://localhost:8000'),
    tokenStore: InMemoryTokenStore(),
  );
  final password = 'live-${newIdempotencyKey()}';
  final email =
      '${name.toLowerCase()}-${DateTime.now().microsecondsSinceEpoch}'
      '@example.com';
  final registered = await client.api.auth.register(
    body: RegisterRequest(name: name, email: email, password: password),
  );
  await client.startSession(registered.tokens);
  addTearDown(() async {
    await client.api.account.deleteAccount(
      body: AccountDeleteRequest(password: password),
    );
    await client.close();
  });
  return (
    workspaces: OrganizationsRepository(
      client: client,
      store: InMemorySecureStore(),
    ),
    userId: registered.user.id,
    email: email,
  );
}

void main() {
  test('runs a workspace: rules, an invitation, members, the log', () async {
    if (!await _listening(8000)) {
      markTestSkipped('Run it with `make app-live-test`.');
      return;
    }
    // Widget tests block real network calls. This test is about them.
    HttpOverrides.global = null;

    final guest = await _account('Guest');
    final owner = await _account('Owner');
    final created = await owner.workspaces.create('Live workspace');
    final org = created.id;

    final renamed = await owner.workspaces.update(
      org,
      name: 'Live team',
      policy: const WorkspacePolicy(maxCopiesPerJob: 25, cloudDocuments: false),
    );
    expect(renamed.organization.name, 'Live team');
    expect(renamed.policy.maxCopiesPerJob, 25);
    expect(renamed.policy.cloudDocuments, isFalse);
    expect(await owner.workspaces.details(org), renamed);
    expect((await owner.workspaces.kept())!.single.name, 'Live team');
    expect(await owner.workspaces.features(org), isA<Map<String, bool>>());

    final invitation = await owner.workspaces.invite(
      organizationId: org,
      email: guest.email,
      role: 'operator',
    );
    expect(invitation.code, isNotEmpty);
    expect((await owner.workspaces.invitations(org)).single.email, guest.email);

    // Someone whose address is not verified is not shown invitations by
    // that address: only a verified address is known to be theirs.
    await expectLater(
      guest.workspaces.received(),
      throwsA(
        isA<ApiProblem>().having(
          (e) => e.code,
          'code',
          'auth.email_not_verified',
        ),
      ),
    );
    // The code is proof enough: it was given to them.
    final joined = await guest.workspaces.acceptCode(invitation.code!);
    expect(joined.id, org);
    expect(joined.role, 'operator');
    expect((await guest.workspaces.kept())!.single.id, org);
    expect(await owner.workspaces.invitations(org), isEmpty);

    final members = await owner.workspaces.members(org);
    expect(members.map((m) => m.role).toSet(), {'owner', 'operator'});
    final changed = await owner.workspaces.changeRole(
      organizationId: org,
      userId: guest.userId,
      role: 'user',
    );
    expect(changed.role, 'user');
    // The only owner cannot be made less.
    await expectLater(
      owner.workspaces.changeRole(
        organizationId: org,
        userId: owner.userId,
        role: 'user',
      ),
      throwsA(isA<ApiProblem>()),
    );

    // The guest leaves, comes back, and is taken out.
    await guest.workspaces.leave(organizationId: org, userId: guest.userId);
    expect(await guest.workspaces.kept(), isEmpty);
    expect(await owner.workspaces.members(org), hasLength(1));
    final second = await owner.workspaces.invite(
      organizationId: org,
      email: guest.email,
    );
    await guest.workspaces.acceptCode(second.code!);
    await owner.workspaces.removeMember(
      organizationId: org,
      userId: guest.userId,
    );
    expect(await owner.workspaces.members(org), hasLength(1));

    final unsent = await owner.workspaces.invite(
      organizationId: org,
      email: guest.email,
    );
    await owner.workspaces.revokeInvitation(
      organizationId: org,
      invitationId: unsent.id,
    );
    expect(await owner.workspaces.invitations(org), isEmpty);

    final log = await owner.workspaces.log(org);
    expect(
      log.actions.map((a) => a.action),
      containsAll(<String>['invitation.created', 'invitation.revoked']),
    );

    await owner.workspaces.delete(org);
    expect(await owner.workspaces.list(), isEmpty);
  });
}
