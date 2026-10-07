import 'dart:convert';

import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_store/local_store.dart';

const _me = '/api/v1/users/me';

Map<String, Object?> _auth({String email = 'ada@example.com'}) => {
  'user': userBody(email: email),
  'tokens': tokenResponse('access', 'refresh'),
};

Map<String, Object?> _verified() => {
  ...userBody(),
  'email_verified_at': '2026-10-07T11:00:00Z',
};

void main() {
  late InMemorySecureStore store;
  late FakeApi network;
  late PrinterHubClient client;
  late AuthRepository repository;
  late List<AuthStatus> statuses;

  Map<String, dynamic> bodyOf(RequestOptions request) {
    return request.data as Map<String, dynamic>;
  }

  /// Puts a session from an earlier launch on the device.
  Future<void> signedInBefore() async {
    await SecureTokenStore(
      store,
    ).write(const AuthTokens(accessToken: 'access', refreshToken: 'refresh'));
    await store.write('session.user', jsonEncode(userBody()));
  }

  setUp(() {
    store = InMemorySecureStore();
    network = FakeApi((_) async => FakeResponse(200, userBody()));
    client = PrinterHubClient(
      baseUrl: Uri.parse('https://api.example.com'),
      tokenStore: SecureTokenStore(store),
      httpClientAdapter: network,
    );
    repository = AuthRepository(client: client, store: store);
    statuses = [];
    final subscription = repository.statusChanges.listen(statuses.add);
    addTearDown(subscription.cancel);
    addTearDown(repository.close);
    addTearDown(client.close);
  });

  test('does not know who is signed in before the session is read', () {
    expect(repository.status, const AuthUnknown());
    expect(repository.user, isNull);
  });

  group('restore', () {
    test('is signed out on a new install', () async {
      await repository.restore();

      expect(repository.status, const SignedOut());
    });

    test('opens with the user kept from the last launch', () async {
      await signedInBefore();

      await repository.restore();

      expect(repository.user?.email, 'ada@example.com');
    });

    test('does not use the network', () async {
      await signedInBefore();

      await repository.restore();

      expect(network.requests, isEmpty);
    });

    test('signs out when the kept user cannot be read', () async {
      await signedInBefore();
      await store.write('session.user', '{"from":"an older version"}');

      await repository.restore();

      expect(repository.status, const SignedOut());
    });

    test('signs out when tokens are missing', () async {
      await store.write('session.user', jsonEncode(userBody()));

      await repository.restore();

      expect(repository.status, const SignedOut());
    });
  });

  group('refresh', () {
    setUp(() async {
      await signedInBefore();
      await repository.restore();
      statuses.clear();
    });

    test('picks up changes made to the account elsewhere', () async {
      network.handler = (_) async => FakeResponse(200, _verified());

      await repository.refresh();

      expect(repository.user?.emailVerified, isTrue);
      expect(statuses, hasLength(1));
      expect(network.to(_me), hasLength(1));
    });

    test('stays signed in when the API cannot be reached', () async {
      network.handler = (_) async => throw const FormatException('offline');

      await repository.refresh();

      expect(repository.user?.email, 'ada@example.com');
    });

    test('stays signed in when the API has a problem of its own', () async {
      network.handler = (_) async =>
          FakeResponse.problem(500, 'internal_error');

      await repository.refresh();

      expect(repository.user?.email, 'ada@example.com');
    });

    test('signs out when the API no longer accepts the session', () async {
      network.handler = (_) async =>
          FakeResponse.problem(401, 'auth.session_revoked');

      await repository.refresh();

      expect(repository.status, const SignedOut());
      expect(await client.hasSession, isFalse);
      expect(store.values, isEmpty);
    });

    test('does nothing when signed out', () async {
      await repository.signOut();
      network.requests.clear();

      await repository.refresh();

      expect(network.requests, isEmpty);
    });
  });

  group('signIn', () {
    test('starts a session and keeps the user', () async {
      network.handler = (_) async => FakeResponse(200, _auth());

      final user = await repository.signIn(
        email: 'ada@example.com',
        password: 'correct horse',
      );

      expect(user.name, 'Ada');
      expect(user.emailVerified, isFalse);
      expect(user.appTheme, 'mint');
      expect(repository.status, SignedIn(user));
      expect(statuses, [SignedIn(user)]);
      expect(await client.hasSession, isTrue);
      expect(bodyOf(network.requests.single), {
        'email': 'ada@example.com',
        'password': 'correct horse',
      });
    });

    test('reports wrong credentials and stays signed out', () async {
      network.handler = (_) async =>
          FakeResponse.problem(401, 'auth.invalid_credentials');

      await expectLater(
        repository.signIn(email: 'ada@example.com', password: 'wrong'),
        throwsA(
          isA<ApiProblem>().having(
            (problem) => problem.code,
            'code',
            'auth.invalid_credentials',
          ),
        ),
      );
      expect(repository.user, isNull);
      expect(await client.hasSession, isFalse);
    });
  });

  test('register creates the account and signs in', () async {
    network.handler = (_) async => FakeResponse(201, _auth());

    final user = await repository.register(
      name: 'Ada',
      email: 'ada@example.com',
      password: 'correct horse',
    );

    expect(repository.status, SignedIn(user));
    expect(network.requests.single.path, '/api/v1/auth/register');
    expect(bodyOf(network.requests.single)['name'], 'Ada');
  });

  group('when signed in', () {
    setUp(() async {
      network.handler = (_) async => FakeResponse(200, _auth());
      await repository.signIn(email: 'ada@example.com', password: 'pw');
      network.requests.clear();
      statuses.clear();
    });

    test('signOut revokes the session and forgets it here', () async {
      network.handler = (_) async => const FakeResponse(204);

      await repository.signOut();

      expect(network.requests.single.path, '/api/v1/auth/logout');
      expect(repository.status, const SignedOut());
      expect(store.values, isEmpty);
    });

    test('signOut works offline', () async {
      network.handler = (_) async => throw const FormatException('offline');

      await repository.signOut();

      expect(repository.status, const SignedOut());
      expect(await client.hasSession, isFalse);
    });

    test('verifyEmail marks the address as verified', () async {
      network.handler = (_) async => FakeResponse(200, _verified());

      final user = await repository.verifyEmail('123456');

      expect(user.emailVerified, isTrue);
      expect(repository.user, user);
      expect(bodyOf(network.requests.single), {'code': '123456'});
    });

    test('resendVerification asks for a new code', () async {
      network.handler = (_) async => const FakeResponse(204);

      await repository.resendVerification();

      expect(network.requests.single.path, '/api/v1/auth/email/resend');
    });

    test('changePassword sends both passwords', () async {
      network.handler = (_) async => const FakeResponse(204);

      await repository.changePassword(
        currentPassword: 'old password',
        newPassword: 'new password',
      );

      expect(bodyOf(network.requests.single), {
        'current_password': 'old password',
        'new_password': 'new password',
      });
    });

    test('updateName renames the user', () async {
      network.handler = (_) async =>
          FakeResponse(200, {...userBody(), 'name': 'Ada L.'});

      final user = await repository.updateName('Ada L.');

      expect(user.name, 'Ada L.');
      expect(bodyOf(network.requests.single), {'name': 'Ada L.'});
    });

    test('savePreferences changes one and sends the rest back', () async {
      network.handler = (request) async => FakeResponse(200, {
        ...userBody(),
        'preferences': bodyOf(request)['preferences'],
      });

      final themed = await repository.savePreferences(appTheme: 'volt');
      final moved = await repository.savePreferences(
        defaultOrganizationId: '0198c0de-0000-7000-8000-00000000000b',
      );

      expect(themed.appTheme, 'volt');
      expect(moved.appTheme, 'volt');
      expect(
        moved.defaultOrganizationId,
        '0198c0de-0000-7000-8000-00000000000b',
      );
      expect(bodyOf(network.requests.first)['preferences'], {
        'app_theme': 'volt',
        'theme': 'system',
        'muted_notification_types': <String>[],
      });
    });

    test('sessions lists where the account is signed in', () async {
      network.handler = (_) async => const FakeResponse(200, [
        {
          'id': '0198c0de-0000-7000-8000-000000000001',
          'device_id': null,
          'user_agent': 'PrinterHub/1.0 iOS',
          'ip': '203.0.113.7',
          'created_at': '2026-10-01T10:00:00Z',
          'last_used_at': '2026-10-07T10:00:00Z',
          'expires_at': '2026-11-01T10:00:00Z',
          'is_current': true,
        },
      ]);

      final sessions = await repository.sessions();

      expect(sessions.single.isCurrent, isTrue);
      expect(sessions.single.userAgent, 'PrinterHub/1.0 iOS');
      expect(sessions.single.ip, '203.0.113.7');
      expect(sessions.single.lastUsedAt, DateTime.utc(2026, 10, 7, 10));
    });

    test('revokeSession signs another device out', () async {
      network.handler = (_) async => const FakeResponse(204);

      await repository.revokeSession('abc');

      expect(network.requests.single.path, '/api/v1/auth/sessions/abc');
      expect(network.requests.single.method, 'DELETE');
    });

    test('deleteAccount deletes it and signs out', () async {
      network.handler = (_) async => const FakeResponse(204);

      await repository.deleteAccount(password: 'correct horse');

      expect(bodyOf(network.requests.single), {'password': 'correct horse'});
      expect(repository.status, const SignedOut());
    });

    test(
      'deleteAccount keeps the session when the password is wrong',
      () async {
        network.handler = (_) async =>
            FakeResponse.problem(403, 'account.password_incorrect');

        await expectLater(
          repository.deleteAccount(password: 'wrong'),
          throwsA(isA<ApiProblem>()),
        );
        expect(repository.user, isNotNull);
      },
    );

    test('signs out when the session can no longer be renewed', () async {
      network.handler = (request) async =>
          request.path == '/api/v1/auth/refresh'
          ? FakeResponse.problem(401, 'auth.refresh_token_invalid')
          : FakeResponse.problem(401, AuthInterceptor.expiredTokenCode);

      await expectLater(repository.sessions(), throwsA(isA<ApiProblem>()));
      await Future<void>.delayed(Duration.zero);

      expect(repository.status, const SignedOut());
      expect(statuses, [const SignedOut()]);
    });
  });

  group('password reset', () {
    test('asks for a code by email', () async {
      network.handler = (_) async => const FakeResponse(202);

      await repository.requestPasswordReset('ada@example.com');

      expect(network.requests.single.path, '/api/v1/auth/password/forgot');
      expect(bodyOf(network.requests.single), {'email': 'ada@example.com'});
    });

    test('sets the new password with the code', () async {
      network.handler = (_) async => const FakeResponse(204);

      await repository.resetPassword(
        email: 'ada@example.com',
        code: '123456',
        newPassword: 'new password',
      );

      expect(bodyOf(network.requests.single), {
        'email': 'ada@example.com',
        'code': '123456',
        'new_password': 'new password',
      });
    });
  });

  test('users with the same details are equal', () {
    final a = User.fromApi(UserRead.fromJson(userBody().cast()));
    final b = User.fromApi(UserRead.fromJson(userBody().cast()));

    expect(a, b);
    expect(
      const SignedIn(
        User(
          id: '1',
          email: 'a@example.com',
          name: 'A',
          emailVerified: false,
          appTheme: 'volt',
        ),
      ),
      isNot(SignedIn(a)),
    );
    expect(const AuthUnknown(), isNot(const SignedOut()));
    // Built at run time on purpose, so equality is compared by value.
    // ignore: prefer_const_constructors
    expect(SignedOut(), SignedOut());
    final lastUsed = DateTime.utc(2026, 10, 7);
    expect(
      UserSession(id: '1', isCurrent: true, lastUsedAt: lastUsed),
      UserSession(id: '1', isCurrent: true, lastUsedAt: lastUsed),
    );
  });
}
