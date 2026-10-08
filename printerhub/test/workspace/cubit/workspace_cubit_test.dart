import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organizations_repository/organizations_repository.dart';
import 'package:printerhub/workspace/workspace.dart';

import '../../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';
const _me = '0198c0de-0000-7000-8000-000000000002';

void main() {
  late TestBackend backend;

  setUp(() async {
    backend = TestBackend();
    await backend.signedInBefore();
  });
  tearDown(() => backend.close());

  WorkspaceCubit build() => WorkspaceCubit(
    organizationsRepository: backend.organizations,
    organizationId: _org,
    userId: _me,
  );

  Future<WorkspaceCubit> loaded() async {
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.load();
    return cubit;
  }

  blocTest<WorkspaceCubit, WorkspaceState>(
    'reads the workspace with its rules',
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => [
      const WorkspaceState(),
      isA<WorkspaceState>()
          .having((s) => s.status, 'status', WorkspaceStatus.ready)
          .having((s) => s.workspace!.organization.name, 'name', 'Acme')
          .having((s) => s.workspace!.policy.cloudDocuments, 'cloud', isTrue),
    ],
  );

  blocTest<WorkspaceCubit, WorkspaceState>(
    'says why the workspace cannot be read',
    setUp: () => backend.offline = true,
    build: build,
    act: (cubit) => cubit.load(),
    skip: 1,
    expect: () => [
      isA<WorkspaceState>()
          .having((s) => s.status, 'status', WorkspaceStatus.failed)
          .having((s) => s.error, 'error', isA<ApiUnreachable>()),
    ],
  );

  test('saves the name and the rules', () async {
    final cubit = await loaded();

    final saving = cubit.save(
      name: 'Acme Ltd',
      policy: const WorkspacePolicy(maxCopiesPerJob: 20, cloudDocuments: false),
    );
    expect(cubit.state.busy, isTrue);
    await saving;

    expect(cubit.state.done, WorkspaceDone.saved);
    expect(cubit.state.busy, isFalse);
    expect(cubit.state.workspace!.organization.name, 'Acme Ltd');
    expect(cubit.state.workspace!.policy.maxCopiesPerJob, 20);
    expect(cubit.state.workspace!.policy.cloudDocuments, isFalse);
    expect(backend.workspaces.single['name'], 'Acme Ltd');
  });

  test('leaves the workspace', () async {
    final cubit = await loaded();

    await cubit.leave();

    expect(cubit.state.done, WorkspaceDone.left);
    expect(backend.workspaces, isEmpty);
    expect(await backend.organizations.kept(), isEmpty);
  });

  test('deletes the workspace', () async {
    final cubit = await loaded();

    await cubit.delete();

    expect(cubit.state.done, WorkspaceDone.deleted);
    expect(cubit.state.workspace!.organization.name, 'Acme');
    expect(backend.workspaces, isEmpty);
  });

  test(
    'says why a change could not be made, and keeps the workspace',
    () async {
      final cubit = await loaded();
      backend.fail('DELETE /organizations/$_org', 403, 'permission.denied');

      await cubit.delete();

      expect(cubit.state.error, isA<ApiProblem>());
      expect(cubit.state.done, isNull);
      expect(cubit.state.busy, isFalse);
      expect(cubit.state.workspace, isNotNull);
    },
  );

  test('makes one change at a time, and none before it has loaded', () async {
    final unloaded = build();
    addTearDown(unloaded.close);
    await unloaded.delete();
    expect(backend.workspaces, hasLength(1));

    final cubit = await loaded();
    final first = cubit.save(name: 'One', policy: const WorkspacePolicy());
    await cubit.save(name: 'Two', policy: const WorkspacePolicy());
    await first;

    expect(backend.workspaces.single['name'], 'One');
  });

  test('says nothing once the screen has gone', () async {
    for (final arrange in <void Function()>[
      () {},
      () => backend.offline = true,
    ]) {
      backend.offline = false;
      final cubit = build();
      arrange();
      final loading = cubit.load();
      await cubit.close();
      await expectLater(loading, completes);
    }
    backend.offline = false;

    for (final arrange in <void Function()>[
      () {},
      () => backend.offline = true,
    ]) {
      backend.offline = false;
      final cubit = build();
      await cubit.load();
      arrange();
      final saving = cubit.save(name: 'Late', policy: const WorkspacePolicy());
      await cubit.close();
      await expectLater(saving, completes);
    }
  });

  test('a workspace body has what the fake backend gives', () {
    expect(organizationBody()['role'], 'owner');
  });
}
