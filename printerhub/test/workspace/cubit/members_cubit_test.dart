import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/workspace/workspace.dart';

import '../../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';

void main() {
  late TestBackend backend;

  setUp(() async {
    backend = TestBackend()..invitationList = [invitationBody()];
    await backend.signedInBefore();
  });
  tearDown(() => backend.close());

  MembersCubit build({bool canManage = true}) => MembersCubit(
    organizationsRepository: backend.organizations,
    organizationId: _org,
    canManage: canManage,
  );

  Future<MembersCubit> loaded({bool canManage = true}) async {
    final cubit = build(canManage: canManage);
    addTearDown(cubit.close);
    await cubit.load();
    return cubit;
  }

  test('lists the people by name, and who is invited', () async {
    backend.memberList = backend.memberList.reversed.toList();

    final cubit = await loaded();

    expect(cubit.state.status, MembersStatus.ready);
    expect(cubit.state.members.map((m) => m.name), ['Ada', 'Grace Hopper']);
    expect(cubit.state.invitations.single.email, 'grace@example.com');
  });

  test(
    'does not ask for invitations for someone who may not see them',
    () async {
      final cubit = await loaded(canManage: false);

      expect(cubit.state.members, hasLength(2));
      expect(cubit.state.invitations, isEmpty);
      expect(backend.sent('GET /organizations/$_org/invitations'), isEmpty);
    },
  );

  test('says why the people cannot be read', () async {
    backend.offline = true;

    final cubit = await loaded();

    expect(cubit.state.status, MembersStatus.failed);
    expect(cubit.state.error, isA<ApiUnreachable>());
  });

  test('invites someone, and has the code to pass on', () async {
    final cubit = await loaded();

    final inviting = cubit.invite(email: 'alan@example.com', role: 'admin');
    expect(cubit.state.busy, isTrue);
    await inviting;

    expect(cubit.state.sent!.email, 'alan@example.com');
    expect(cubit.state.sent!.role, 'admin');
    expect(cubit.state.sent!.code, 'code-invitation-2');
    expect(cubit.state.invitations, hasLength(2));
    expect(cubit.state.busy, isFalse);
  });

  test('says why someone could not be invited', () async {
    final cubit = await loaded();
    backend.fail(
      'POST /organizations/$_org/invitations',
      409,
      'invitation.already_member',
    );

    await cubit.invite(email: 'grace@example.com', role: 'user');

    expect(cubit.state.error, isA<ApiProblem>());
    expect(cubit.state.sent, isNull);
    expect(cubit.state.invitations, hasLength(1));
  });

  test('takes an invitation back', () async {
    final cubit = await loaded();

    await cubit.revoke(cubit.state.invitations.single);

    expect(cubit.state.invitations, isEmpty);
    expect(backend.invitationList, isEmpty);
  });

  test('gives someone another role', () async {
    final cubit = await loaded();

    await cubit.changeRole(cubit.state.members.last, 'admin');

    expect(cubit.state.members.last.role, 'admin');
  });

  test('removes someone', () async {
    final cubit = await loaded();

    await cubit.remove(cubit.state.members.last);

    expect(cubit.state.members.single.name, 'Ada');
  });

  test('makes one change at a time, and none before it has loaded', () async {
    final unloaded = build();
    addTearDown(unloaded.close);
    await unloaded.invite(email: 'alan@example.com', role: 'user');
    expect(backend.invitationList, hasLength(1));

    final cubit = await loaded();
    final first = cubit.remove(cubit.state.members.last);
    await cubit.revoke(cubit.state.invitations.single);
    await first;

    expect(backend.memberList, hasLength(1));
    expect(backend.invitationList, hasLength(1));
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

    for (final offline in [false, true]) {
      final cubit = build();
      await cubit.load();
      backend.offline = offline;
      final inviting = cubit.invite(email: 'alan@example.com', role: 'user');
      await cubit.close();
      await expectLater(inviting, completes);
      backend.offline = false;
    }
  });
}
