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
  group('this phone', () {
    const phone = PhoneDetails(
      platform: 'ios',
      model: 'iPhone 15 Pro',
      osVersion: '18.1',
      appVersion: '1.0.0 (1)',
    );

    Map<String, Object?> deviceBody({
      String id = 'device-1',
      String installationId = 'install-1',
      bool pushEnabled = false,
    }) => {
      'id': id,
      'installation_id': installationId,
      'platform': 'ios',
      'name': null,
      'model': 'iPhone 15 Pro',
      'os_version': '18.1',
      'app_version': '1.0.0 (1)',
      'push_provider': pushEnabled ? 'fcm' : null,
      'push_enabled': pushEnabled,
      'last_seen_at': '2026-10-07T10:00:00Z',
      'created_at': '2026-10-01T10:00:00Z',
    };

    late AuthRepository withPhone;

    /// Answers sign-in, the account, and device registration.
    void serve() {
      network.handler = (request) async {
        if (request.path.endsWith('/devices')) {
          return request.method == 'POST'
              ? FakeResponse(
                  200,
                  deviceBody(
                    installationId:
                        bodyOf(request)['installation_id'] as String,
                    pushEnabled: bodyOf(request)['push_token'] != null,
                  ),
                )
              : FakeResponse(200, [
                  deviceBody(installationId: store.values['installation.id']!),
                  deviceBody(id: 'device-2', installationId: 'another-phone'),
                ]);
        }
        if (request.path.endsWith('/auth/login')) {
          return FakeResponse(200, _auth());
        }
        return FakeResponse(200, userBody());
      };
    }

    setUp(() {
      withPhone = AuthRepository(
        client: client,
        store: store,
        describePhone: () async => phone,
      );
      addTearDown(withPhone.close);
      serve();
    });

    List<RequestOptions> registrations() => [
      for (final request in network.requests)
        if (request.path.endsWith('/devices') && request.method == 'POST')
          request,
    ];

    test('has one identifier, made once and kept through sign-out', () async {
      final id = await withPhone.installationId();

      expect(id, hasLength(36));
      expect(await withPhone.installationId(), id);
      await withPhone.signOut();
      expect(await withPhone.installationId(), id);
    });

    test('is registered when someone signs in', () async {
      await withPhone.signIn(email: 'ada@example.com', password: 'pw');

      final sent = bodyOf(registrations().single);
      expect(sent['installation_id'], await withPhone.installationId());
      // A name is the person's to give: registering sends none, so the
      // one they gave is kept.
      expect(sent, isNot(contains('name')));
      expect(sent['platform'], 'ios');
      expect(sent['model'], 'iPhone 15 Pro');
      expect(sent['os_version'], '18.1');
      expect(sent['app_version'], '1.0.0 (1)');
      expect(sent.containsKey('push_token'), isFalse);
      expect(sent.containsKey('push_provider'), isFalse);
    });

    test('is registered again each time the app opens', () async {
      await signedInBefore();
      await withPhone.restore();

      await withPhone.refresh();

      expect(registrations(), hasLength(1));
    });

    test('is not registered by a repository that cannot describe it', () async {
      await repository.signIn(email: 'ada@example.com', password: 'pw');

      expect(await repository.registerDevice(), isNull);
      expect(registrations(), isEmpty);
    });

    test('says where its notifications go', () async {
      final device = await withPhone.registerDevice(pushToken: 'fcm-token');

      final sent = bodyOf(registrations().single);
      expect(sent['push_token'], 'fcm-token');
      expect(sent['push_provider'], 'fcm');
      expect(device!.pushEnabled, isTrue);
      expect(device.isThisDevice, isTrue);
    });

    test('a failed registration does not stop a sign-in', () async {
      network.handler = (request) async => request.path.endsWith('/devices')
          ? throw const FormatException('offline')
          : FakeResponse(200, _auth());

      final user = await withPhone.signIn(
        email: 'ada@example.com',
        password: 'pw',
      );

      expect(user.email, 'ada@example.com');
      expect(await withPhone.registerDevice(), isNull);
    });

    test('lists the devices, marking this one', () async {
      await withPhone.installationId();

      final devices = await withPhone.devices();

      expect(devices.map((device) => device.isThisDevice), [true, false]);
      expect(devices.first.label, 'iPhone 15 Pro');
      expect(devices.first.platform, 'ios');
      expect(devices.first.lastSeenAt, DateTime.utc(2026, 10, 7, 10));
      expect(devices.first, isNot(devices.last));
      // Built at run time, so equality is by value and not by identity.
      PhoneDetails described(String model) =>
          PhoneDetails(platform: 'ios', model: model);
      expect(described('iPhone 15'), described('iPhone 15'));
      expect(described('iPhone 15'), isNot(described('iPhone 16')));
    });

    test('a device is called by the best name it has', () {
      final seen = DateTime.utc(2026);
      // The name its owner gave it comes before what it is.
      expect(
        UserDevice(
          id: '1',
          platform: 'android',
          lastSeenAt: seen,
          name: 'Work phone',
          model: 'Pixel 8',
        ).label,
        'Work phone',
      );
      expect(
        UserDevice(
          id: '1',
          platform: 'android',
          lastSeenAt: seen,
          model: 'Pixel 8',
        ).label,
        'Pixel 8',
      );
      expect(
        UserDevice(id: '1', platform: 'android', lastSeenAt: seen).label,
        'android',
      );
      expect(
        UserDevice(
          id: '1',
          platform: 'android',
          lastSeenAt: seen,
          name: "Ada's phone",
        ).label,
        "Ada's phone",
      );
    });

    test('names a device, and changes nothing else about it', () async {
      network.handler = (_) async => const FakeResponse(200, {
        'id': 'device-2',
        'installation_id': 'another-install',
        'platform': 'android',
        'name': 'Work phone',
        'model': 'Pixel 8',
        'os_version': 'Android 15',
        'app_version': '1.0.0 (1)',
        'push_provider': 'fcm',
        'push_enabled': true,
        'last_seen_at': '2026-10-07T10:00:00Z',
        'created_at': '2026-10-01T10:00:00Z',
      });

      final named = await withPhone.renameDevice('device-2', 'Work phone');

      final request = network.requests.single;
      expect(request.method, 'PATCH');
      expect(request.path, '/api/v1/devices/device-2');
      // The name alone: sending the push fields empty would stop push.
      expect(request.data, {'name': 'Work phone'});
      expect(named.label, 'Work phone');
      expect(named.pushEnabled, isTrue);
      expect(named.isThisDevice, isFalse);
    });

    test('removes a device', () async {
      network.handler = (_) async => const FakeResponse(204);

      await withPhone.removeDevice('device-2');

      expect(network.requests.single.method, 'DELETE');
      expect(network.requests.single.path, '/api/v1/devices/device-2');
    });
  });
}
