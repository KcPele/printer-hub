import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/workspace/workspace.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;

  setUp(() async {
    backend = TestBackend()
      ..receivedInvitations = [
        receivedInvitationBody(),
        receivedInvitationBody(
          id: 'invitation-8',
          organizationId: 'org-gamma',
          organizationName: 'Gamma',
          role: 'admin',
        ),
      ];
    await backend.signedInBefore();
  });
  tearDown(() => backend.close());

  InvitationsCubit build() =>
      InvitationsCubit(organizationsRepository: backend.organizations);

  Future<InvitationsCubit> loaded() async {
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.load();
    return cubit;
  }

  void unverified() => backend.fail(
    'GET /invitations',
    403,
    'auth.email_not_verified',
    detail: 'Verify your email address to see and accept invitations.',
  );

  test('lists the invitations the person was sent', () async {
    final cubit = await loaded();

    expect(cubit.state.status, InvitationsStatus.ready);
    expect(cubit.state.invitations.map((i) => i.organizationName), [
      'Beta',
      'Gamma',
    ]);
    expect(cubit.state.needsVerifiedEmail, isFalse);
  });

  test('says why the invitations cannot be read', () async {
    backend.offline = true;

    final cubit = await loaded();

    expect(cubit.state.status, InvitationsStatus.failed);
    expect(cubit.state.error, isA<ApiUnreachable>());
    expect(cubit.state.needsVerifiedEmail, isFalse);
  });

  test('is still ready for a code when the email is not verified', () async {
    unverified();

    final cubit = await loaded();

    expect(cubit.state.status, InvitationsStatus.ready);
    expect(cubit.state.needsVerifiedEmail, isTrue);
    expect(cubit.state.invitations, isEmpty);
  });

  test('joins the workspace an invitation is to', () async {
    final cubit = await loaded();

    final joining = cubit.accept(cubit.state.invitations.first);
    expect(cubit.state.busy, isTrue);
    await joining;

    expect(cubit.state.joined!.name, 'Beta');
    expect(cubit.state.invitations.single.organizationName, 'Gamma');
    expect(cubit.state.busy, isFalse);
    expect(backend.workspaces.map((w) => w['name']), ['Acme', 'Beta']);
  });

  test('joins by a code, though the email is not verified', () async {
    unverified();
    final cubit = await loaded();

    await cubit.acceptCode('  code-invitation-8 ');

    expect(cubit.state.joined!.name, 'Gamma');
    // The notice about the address is still true.
    expect(cubit.state.needsVerifiedEmail, isTrue);
  });

  test('says why a workspace could not be joined', () async {
    final cubit = await loaded();

    await cubit.acceptCode('not-a-code');

    expect(cubit.state.error, isA<ApiProblem>());
    expect(cubit.state.joined, isNull);
    expect(cubit.state.invitations, hasLength(2));
    expect(cubit.state.busy, isFalse);
  });

  test('joins one at a time, and not before it has loaded', () async {
    final unloaded = build();
    addTearDown(unloaded.close);
    await unloaded.acceptCode('code-invitation-9');
    expect(backend.workspaces, hasLength(1));

    final cubit = await loaded();
    final [beta, gamma] = cubit.state.invitations;
    final first = cubit.accept(beta);
    await cubit.accept(gamma);
    await first;

    expect(backend.workspaces, hasLength(2));
  });

  test('says nothing once the screen has gone', () async {
    for (final offline in [false, true]) {
      backend.offline = offline;
      final cubit = build();
      final loading = cubit.load();
      await cubit.close();
      await expectLater(loading, completes);
    }
    backend.offline = false;

    for (final code in ['code-invitation-9', 'not-a-code']) {
      final cubit = build();
      await cubit.load();
      final joining = cubit.acceptCode(code);
      await cubit.close();
      await expectLater(joining, completes);
    }
  });
}
