import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:organizations_repository/organizations_repository.dart';
import 'package:printerhub/session/session.dart';

import '../../helpers/helpers.dart';

const _acme = Organization(id: 'acme', name: 'Acme', role: 'owner');
const _globex = Organization(id: 'globex', name: 'Globex', role: 'user');

void main() {
  late TestBackend backend;
  late MockPreferencesRepository preferences;

  setUp(() {
    backend = TestBackend();
    preferences = emptyPreferences();
  });
  tearDown(() => backend.close());

  Future<SessionCubit> build({bool useKept = true}) async {
    final cubit = SessionCubit(
      authRepository: backend.auth,
      organizationsRepository: backend.organizations,
      preferencesRepository: preferences,
      keptOrganizations: useKept ? await backend.organizations.kept() : null,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  void twoWorkspaces() {
    backend.workspaces = [
      organizationBody(id: 'acme'),
      organizationBody(id: 'globex', name: 'Globex', role: 'user'),
    ];
  }

  // Lets the requests a status change set off run to their end.
  Future<void> settle() => pumpEventQueue();

  group('at launch', () {
    test('is signed out when nobody is signed in', () async {
      final cubit = await build();

      expect(cubit.state, const SessionState.signedOut());
    });

    test('is ready at once for a returning user', () async {
      await backend.signedInBefore();

      final cubit = await build();

      expect(cubit.state.stage, SessionStage.ready);
      expect(cubit.state.user?.email, 'ada@example.com');
      expect(cubit.state.organization?.name, 'Acme');
      expect(backend.network.requests, isEmpty);
    });

    test('loads workspaces when none were kept', () async {
      await backend.signedInBefore();

      final cubit = await build(useKept: false);
      expect(cubit.state.stage, SessionStage.loading);

      await cubit.refresh();
      expect(cubit.state.stage, SessionStage.ready);
    });

    test('refresh brings the account and workspaces up to date', () async {
      await backend.signedInBefore();
      final cubit = await build();
      backend
        ..user = {...backend.user, 'name': 'Ada L.'}
        ..workspaces = [organizationBody(name: 'Acme Ltd')];

      await cubit.refresh();

      expect(cubit.state.user?.name, 'Ada L.');
      expect(cubit.state.organization?.name, 'Acme Ltd');
    });

    test('refresh keeps a returning user going when offline', () async {
      await backend.signedInBefore();
      final cubit = await build();
      backend.offline = true;

      await cubit.refresh();

      expect(cubit.state.stage, SessionStage.ready);
      expect(cubit.state.organization?.name, 'Acme');
    });

    test('refresh does nothing when signed out', () async {
      final cubit = await build();

      await cubit.refresh();
      await cubit.loadWorkspaces();

      expect(backend.network.requests, isEmpty);
    });
  });

  group('signing in', () {
    test('loads the workspaces and uses the first', () async {
      twoWorkspaces();
      final cubit = await build();
      final stages = <SessionStage>[];
      final subscription = cubit.stream.listen((s) => stages.add(s.stage));
      addTearDown(subscription.cancel);

      await backend.auth.signIn(email: 'ada@example.com', password: 'pw');
      await settle();

      expect(stages, [SessionStage.loading, SessionStage.ready]);
      expect(cubit.state.organizations, [_acme, _globex]);
      expect(cubit.state.organization, _acme);
    });

    test('prefers the workspace last used on this device', () async {
      twoWorkspaces();
      preferences = emptyPreferences(activeOrganizationId: 'globex');
      final cubit = await build();

      await backend.auth.signIn(email: 'ada@example.com', password: 'pw');
      await settle();

      expect(cubit.state.organization, _globex);
    });

    test('then the workspace last used on any device', () async {
      twoWorkspaces();
      backend.user = {
        ...backend.user,
        'preferences': {
          ...backend.user['preferences']! as Map<String, Object?>,
          'default_organization_id': 'globex',
        },
      };
      final cubit = await build();

      await backend.auth.signIn(email: 'ada@example.com', password: 'pw');
      await settle();

      expect(cubit.state.organization, _globex);
    });

    test('asks for a workspace when there is none', () async {
      final cubit = await build();

      await backend.auth.signIn(email: 'ada@example.com', password: 'pw');
      await settle();

      expect(cubit.state.stage, SessionStage.needsWorkspace);
      expect(cubit.state.organization, isNull);
    });

    test(
      'fails when the workspaces cannot be fetched, and can retry',
      () async {
        backend.fail('GET /organizations', 500, 'internal_error');
        final cubit = await build();

        await backend.auth.signIn(email: 'ada@example.com', password: 'pw');
        await settle();
        expect(cubit.state.stage, SessionStage.failed);
        expect(cubit.state.error, isA<ApiProblem>());

        backend.routes.clear();
        backend.workspaces = [organizationBody(id: 'acme')];
        await cubit.retry();
        expect(cubit.state.stage, SessionStage.ready);
      },
    );

    test('follows changes to the user', () async {
      await backend.signedInBefore();
      final cubit = await build();

      await backend.auth.verifyEmail('123456');

      expect(cubit.state.user?.emailVerified, isTrue);
      expect(cubit.state.stage, SessionStage.ready);
    });
  });

  group('workspaces', () {
    test('createWorkspace creates one and starts using it', () async {
      await backend.signedInBefore(withWorkspace: false);
      final cubit = await build();
      await cubit.loadWorkspaces();
      expect(cubit.state.stage, SessionStage.needsWorkspace);

      await cubit.createWorkspace("Ada's workspace");

      expect(cubit.state.stage, SessionStage.ready);
      expect(cubit.state.organization?.name, "Ada's workspace");
      expect(preferences.activeOrganizationId, 'org-1');
      expect(
        (backend.lastBody('PATCH /users/me')['preferences']
            as Map<String, dynamic>)['default_organization_id'],
        'org-1',
      );
    });

    test('createWorkspace reports a failure to its caller', () async {
      await backend.signedInBefore(withWorkspace: false);
      final cubit = await build();
      backend.fail('POST /organizations', 422, 'request.validation_failed');

      await expectLater(cubit.createWorkspace(''), throwsA(isA<ApiProblem>()));
    });

    test('selectWorkspace switches and remembers the choice', () async {
      twoWorkspaces();
      await backend.signedInBefore();
      final cubit = await build();

      await cubit.selectWorkspace(_globex);

      expect(cubit.state.organization, _globex);
      expect(cubit.state.organizations, hasLength(2));
      verify(() => preferences.saveActiveOrganizationId('globex')).called(1);
    });

    test('selectWorkspace still switches when offline', () async {
      twoWorkspaces();
      await backend.signedInBefore();
      final cubit = await build();
      backend.offline = true;

      await cubit.selectWorkspace(_globex);

      expect(cubit.state.organization, _globex);
      expect(preferences.activeOrganizationId, 'globex');
    });

    test('keeps the workspace in use when the list is refreshed', () async {
      twoWorkspaces();
      await backend.signedInBefore();
      final cubit = await build();
      await cubit.selectWorkspace(_globex);

      await cubit.loadWorkspaces();

      expect(cubit.state.organization, _globex);
    });

    test('a failed refresh leaves a ready session alone', () async {
      await backend.signedInBefore();
      final cubit = await build();
      backend.fail('GET /organizations', 500, 'internal_error');

      await cubit.loadWorkspaces();

      expect(cubit.state.stage, SessionStage.ready);
    });
  });

  group('signing out', () {
    test('forgets the user, the workspaces, and the choice', () async {
      await backend.signedInBefore();
      preferences = emptyPreferences(activeOrganizationId: 'acme');
      final cubit = await build();

      await cubit.signOut();
      await settle();

      expect(cubit.state, const SessionState.signedOut());
      expect(await backend.organizations.kept(), isNull);
      expect(preferences.activeOrganizationId, isNull);
    });

    test('drops a workspace answer that arrives after signing out', () async {
      await backend.signedInBefore();
      final cubit = await build(useKept: false);
      backend.routes['GET /organizations'] = (_) async {
        await backend.auth.signOut();
        return FakeResponse(200, [organizationBody()]);
      };

      await cubit.loadWorkspaces();
      await settle();

      expect(cubit.state, const SessionState.signedOut());
    });
  });
}
