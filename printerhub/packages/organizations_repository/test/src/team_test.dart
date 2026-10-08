import 'dart:convert';

import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_store/local_store.dart';
import 'package:organizations_repository/organizations_repository.dart';

const _org = 'org-1';
const _path = '/api/v1/organizations/$_org';

void main() {
  late InMemorySecureStore store;
  late FakeApi api;
  late OrganizationsRepository repository;

  Map<String, dynamic> bodyOf(RequestOptions request) {
    return jsonDecode(jsonEncode(request.data)) as Map<String, dynamic>;
  }

  Map<String, Object?> workspace({
    String id = _org,
    String name = 'Acme',
    String role = 'owner',
    Map<String, Object?> settings = const {},
  }) {
    final body = organizationBody(id: id, name: name, role: role);
    return {
      ...body,
      'settings': {...body['settings']! as Map<String, Object?>, ...settings},
    };
  }

  setUp(() {
    store = InMemorySecureStore();
    api = FakeApi((request) async {
      final path = request.path.replaceFirst('/api/v1', '');
      final method = request.method;
      if (method == 'DELETE') return const FakeResponse(204);
      return switch (path) {
        '/organizations' => FakeResponse(200, [
          workspace(),
          workspace(id: 'org-2', name: 'Globex', role: 'user'),
        ]),
        '/organizations/$_org' when method == 'PATCH' => FakeResponse(
          200,
          workspace(
            name: 'Acme Ltd',
            settings: {
              'max_copies_per_job': 20,
              'document_storage_mode': 'local_only',
            },
          ),
        ),
        '/organizations/$_org' => FakeResponse(
          200,
          workspace(
            settings: {'max_copies_per_job': 50, 'document_retention_days': 30},
          ),
        ),
        '/organizations/$_org/members' => FakeResponse(200, [
          memberBody(),
          memberBody(
            userId: 'user-2',
            name: 'Grace Hopper',
            email: 'grace@example.com',
            role: 'user',
          ),
        ]),
        '/organizations/$_org/members/user-2' => FakeResponse(
          200,
          memberBody(userId: 'user-2', name: 'Grace Hopper', role: 'admin'),
        ),
        '/organizations/$_org/invitations' when method == 'POST' =>
          FakeResponse(201, {
            ...invitationBody(role: 'operator'),
            'token': 'join-code-123',
          }),
        '/organizations/$_org/invitations' => FakeResponse(200, [
          invitationBody(),
        ]),
        '/invitations' => FakeResponse(200, [receivedInvitationBody()]),
        '/invitations/accept' || '/invitations/invitation-9/accept' =>
          FakeResponse(200, workspace(id: 'org-3', name: 'Beta', role: 'user')),
        '/organizations/$_org/audit-logs' => FakeResponse(200, {
          'items': [
            auditBody(
              action: 'invitation.created',
              targetType: 'invitation',
              detail: const {'email': 'grace@example.com', 'role': 'user'},
            ),
            auditBody(
              id: 'audit-2',
              action: 'printer.deleted',
              outcome: 'failure',
              actorUserId: null,
            ),
          ],
          'next_cursor': 'next-page',
        }),
        _ => const FakeResponse(200, {
          'flags': {'scan.ocr': true, 'print.secure': false},
        }),
      };
    });
    final client = PrinterHubClient(
      baseUrl: Uri.parse('https://api.example.com'),
      tokenStore: InMemoryTokenStore(),
      httpClientAdapter: api,
    );
    addTearDown(client.close);
    repository = OrganizationsRepository(client: client, store: store);
  });

  Future<List<String>> keptNames() async => [
    for (final kept in await repository.kept() ?? <Organization>[]) kept.name,
  ];

  group('a workspace', () {
    test('is read with its rules', () async {
      final workspace = await repository.details(_org);

      expect(api.requests.single.path, _path);
      expect(workspace.organization.name, 'Acme');
      expect(workspace.organization.canManage, isTrue);
      expect(workspace.policy.maxCopiesPerJob, 50);
      expect(workspace.policy.cloudDocuments, isTrue);
      expect(workspace.policy.documentRetentionDays, 30);
      expect(workspace.policy.colorPrintingRoles, contains('operator'));
      expect(
        workspace,
        Workspace.fromApi(
          OrganizationRead.fromJson(
            {
              ...organizationBody(id: _org),
              'settings': {
                ...organizationBody()['settings']! as Map<String, Object?>,
                'max_copies_per_job': 50,
                'document_retention_days': 30,
              },
            }.cast(),
          ),
        ),
      );
    });

    test('is renamed and given new rules, and the kept list learns the '
        'name', () async {
      await repository.list();
      api.requests.clear();

      final updated = await repository.update(
        _org,
        name: 'Acme Ltd',
        policy: const WorkspacePolicy(
          maxCopiesPerJob: 20,
          cloudDocuments: false,
          colorPrintingRoles: ['owner', 'admin'],
        ),
      );

      final sent = bodyOf(api.requests.single);
      expect(api.requests.single.method, 'PATCH');
      expect(sent['name'], 'Acme Ltd');
      expect(sent['settings'], {
        'max_copies_per_job': 20,
        'document_storage_mode': 'local_only',
        'color_printing_roles': ['owner', 'admin'],
      });
      expect(updated.organization.name, 'Acme Ltd');
      expect(updated.policy.cloudDocuments, isFalse);
      expect(await keptNames(), ['Acme Ltd', 'Globex']);
    });

    test('is changed in name alone, with no list kept yet', () async {
      await repository.update(_org, name: 'Acme Ltd');

      final sent = bodyOf(api.requests.single);
      expect(sent['name'], 'Acme Ltd');
      expect(sent['settings'], isNull);
      expect(await keptNames(), isEmpty);
    });

    test('is deleted, and leaves the kept list', () async {
      await repository.list();

      await repository.delete(_org);

      expect(api.requests.last.method, 'DELETE');
      expect(api.requests.last.path, _path);
      expect(await keptNames(), ['Globex']);
    });

    test('says what is switched on for it', () async {
      final features = await repository.features(_org);

      expect(api.requests.single.path, '$_path/feature-flags');
      expect(features, {'scan.ocr': true, 'print.secure': false});
    });
  });

  test('rules change one at a time, and compare by value', () {
    const policy = WorkspacePolicy();

    expect(policy, const WorkspacePolicy());
    expect(policy.maxCopiesPerJob, isNull);
    expect(policy.copyWith(maxCopiesPerJob: () => 5).maxCopiesPerJob, 5);
    expect(policy.copyWith(cloudDocuments: false).cloudDocuments, isFalse);
    expect(
      policy
          .copyWith(documentRetentionDays: () => 7)
          .copyWith(cloudDocuments: false)
          .documentRetentionDays,
      7,
    );
    expect(WorkspacePolicy.fromJson(const {}).cloudDocuments, isTrue);
    expect(WorkspacePolicy.fromJson(const {}).colorPrintingRoles, isEmpty);
    expect(policy.toApi().toJson()['document_storage_mode'], 'cloud_allowed');
  });

  group('members', () {
    test('are listed with their roles', () async {
      final members = await repository.members(_org);

      expect(api.requests.single.path, '$_path/members');
      expect(members.map((m) => m.name), ['Ada Lovelace', 'Grace Hopper']);
      expect(members.last.email, 'grace@example.com');
      expect(members.last.role, 'user');
      expect(members.last.userId, 'user-2');
      expect(members.last.joinedAt, DateTime.utc(2026, 10, 7, 10));
      expect(
        members.first,
        Member.fromApi(MemberRead.fromJson(memberBody().cast())),
      );
    });

    test('are given another role', () async {
      final changed = await repository.changeRole(
        organizationId: _org,
        userId: 'user-2',
        role: 'admin',
      );

      expect(api.requests.single.method, 'PATCH');
      expect(bodyOf(api.requests.single), {'role': 'admin'});
      expect(changed.role, 'admin');
    });

    test('are removed', () async {
      await repository.removeMember(organizationId: _org, userId: 'user-2');

      expect(api.requests.single.method, 'DELETE');
      expect(api.requests.single.path, '$_path/members/user-2');
    });

    test('leave, and the workspace leaves the kept list', () async {
      await repository.list();

      await repository.leave(organizationId: _org, userId: 'user-1');

      expect(api.requests.last.path, '$_path/members/user-1');
      expect(await keptNames(), ['Globex']);
    });
  });

  group('invitations', () {
    test('are sent, and come back with the code to join with', () async {
      final invitation = await repository.invite(
        organizationId: _org,
        email: 'grace@example.com',
        role: 'operator',
      );

      expect(bodyOf(api.requests.single), {
        'email': 'grace@example.com',
        'role': 'operator',
      });
      expect(invitation.code, 'join-code-123');
      expect(invitation.role, 'operator');
      expect(invitation.expiresAt, DateTime.utc(2026, 10, 14, 10));
    });

    test('are for an ordinary member unless said otherwise', () async {
      await repository.invite(organizationId: _org, email: 'g@example.com');

      expect(bodyOf(api.requests.single)['role'], 'user');
    });

    test('that are waiting are listed, without their codes', () async {
      final waiting = await repository.invitations(_org);

      expect(waiting.single.email, 'grace@example.com');
      expect(waiting.single.code, isNull);
      expect(
        waiting.single,
        Invitation(
          id: 'invitation-1',
          email: 'grace@example.com',
          role: 'user',
          expiresAt: DateTime.utc(2026, 10, 14, 10),
        ),
      );
    });

    test('are taken back', () async {
      await repository.revokeInvitation(
        organizationId: _org,
        invitationId: 'invitation-1',
      );

      expect(api.requests.single.method, 'DELETE');
      expect(api.requests.single.path, '$_path/invitations/invitation-1');
    });

    test('that the person was sent are listed', () async {
      final received = await repository.received();

      expect(api.requests.single.path, '/api/v1/invitations');
      expect(received.single.organizationName, 'Beta');
      expect(received.single.role, 'user');
      expect(
        received.single,
        ReceivedInvitation.fromApi(
          MyInvitationRead.fromJson(receivedInvitationBody().cast()),
        ),
      );
    });

    test('are accepted, and the workspace joins the kept list', () async {
      await repository.list();

      final joined = await repository.accept('invitation-9');

      expect(api.requests.last.path, '/api/v1/invitations/invitation-9/accept');
      expect(joined.name, 'Beta');
      expect(await keptNames(), ['Acme', 'Globex', 'Beta']);

      // Joined again, it is still there once.
      await repository.accept('invitation-9');
      expect(await keptNames(), ['Acme', 'Globex', 'Beta']);
    });

    test('are accepted by their code', () async {
      final joined = await repository.acceptCode('join-code-123');

      expect(api.requests.single.path, '/api/v1/invitations/accept');
      expect(bodyOf(api.requests.single), {'token': 'join-code-123'});
      expect(joined.id, 'org-3');
      expect(await keptNames(), ['Beta']);
    });
  });

  group('the log', () {
    test('is a page of what was done, newest first', () async {
      final page = await repository.log(_org);

      expect(api.requests.single.path, '$_path/audit-logs');
      expect(page.next, 'next-page');
      final [invited, failed] = page.actions;
      expect(invited.action, 'invitation.created');
      expect(invited.targetType, 'invitation');
      expect(invited.succeeded, isTrue);
      expect(invited.actorUserId, 'user-1');
      expect(invited.detail['email'], 'grace@example.com');
      expect(invited.at, DateTime.utc(2026, 10, 7, 10));
      expect(failed.succeeded, isFalse);
      expect(failed.actorUserId, isNull);
      expect(failed.detail, isEmpty);
      expect(
        invited,
        LoggedAction.fromApi(
          AuditLogRead.fromJson(
            auditBody(
              action: 'invitation.created',
              targetType: 'invitation',
              detail: const {'email': 'grace@example.com', 'role': 'user'},
            ).cast(),
          ),
        ),
      );
    });

    test('is read on', () async {
      await repository.log(_org, cursor: 'next-page');

      expect(api.requests.single.queryParameters['cursor'], 'next-page');
    });

    test('makes do with a detail that is not a list of facts', () {
      final odd = LoggedAction.fromApi(
        AuditLogRead.fromJson({...auditBody(), 'detail': 'none'}.cast()),
      );

      expect(odd.detail, isEmpty);
    });
  });
}
