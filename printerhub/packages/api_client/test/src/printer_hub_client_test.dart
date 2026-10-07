import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

const _me = '/api/v1/users/me';
const _refresh = '/api/v1/auth/refresh';
const _login = '/api/v1/auth/login';

void main() {
  const stored = AuthTokens(
    accessToken: 'old-access',
    refreshToken: 'old-refresh',
  );

  late InMemoryTokenStore store;
  late FakeApi network;
  late PrinterHubClient client;

  String? authorization(RequestOptions request) =>
      request.headers['Authorization'] as String?;

  /// An API where `old-access` has expired and `old-refresh` renews it.
  Future<FakeResponse> expiring(RequestOptions request) async {
    if (request.path == _refresh) {
      return FakeResponse(200, tokenResponse('new-access', 'new-refresh'));
    }
    if (authorization(request) == 'Bearer new-access') {
      return FakeResponse(200, userBody());
    }
    return FakeResponse.problem(401, AuthInterceptor.expiredTokenCode);
  }

  setUp(() {
    store = InMemoryTokenStore(stored);
    network = FakeApi((_) async => FakeResponse(200, userBody()));
    client = PrinterHubClient(
      baseUrl: Uri.parse('https://api.example.com/'),
      tokenStore: store,
      httpClientAdapter: network,
    );
  });

  tearDown(() => client.close());

  group('requests', () {
    test('go to the base URL and decode the response', () async {
      final user = await client.api.users.getMe();

      expect(user.email, 'ada@example.com');
      expect(user.preferences.appTheme.json, 'mint');
      expect(
        network.requests.single.uri.toString(),
        'https://api.example.com$_me',
      );
    });

    test('carry the access token', () async {
      await client.api.users.getMe();

      expect(authorization(network.requests.single), 'Bearer old-access');
    });

    test('carry no token when there is no session', () async {
      await store.clear();

      await client.api.users.getMe();

      expect(authorization(network.requests.single), isNull);
    });

    test('carry no token to sign in', () async {
      network.handler = (_) async => FakeResponse(200, {
        'user': userBody(),
        'tokens': tokenResponse('a', 'r'),
      });

      await client.api.auth.login(
        body: const LoginRequest(
          email: 'ada@example.com',
          password: 'correct horse',
        ),
      );

      expect(authorization(network.requests.single), isNull);
    });

    test('surface an API error as a problem', () async {
      network.handler = (_) async => FakeResponse.problem(
        403,
        'auth.email_not_verified',
        detail: 'Verify your email.',
      );

      await expectLater(
        apiCall(() => client.api.users.getMe()),
        throwsA(
          isA<ApiProblem>()
              .having((p) => p.code, 'code', 'auth.email_not_verified')
              .having((p) => p.detail, 'detail', 'Verify your email.')
              .having((p) => p.requestId, 'requestId', 'req-1'),
        ),
      );
    });

    test('surface a network failure as unreachable', () async {
      network.handler = (_) async =>
          throw const FormatException('connection reset');

      await expectLater(
        apiCall(() => client.api.users.getMe()),
        throwsA(isA<ApiUnreachable>()),
      );
    });
  });

  group('an expired access token', () {
    setUp(() => network.handler = expiring);

    test('is renewed and the request is sent again', () async {
      final user = await client.api.users.getMe();

      expect(user.email, 'ada@example.com');
      expect(network.to(_me).map(authorization), [
        'Bearer old-access',
        'Bearer new-access',
      ]);
      expect(network.to(_refresh).single.data, {
        'refresh_token': 'old-refresh',
      });
      expect(
        await store.read(),
        const AuthTokens(
          accessToken: 'new-access',
          refreshToken: 'new-refresh',
        ),
      );
    });

    test('is renewed once for requests that expire together', () async {
      final users = await Future.wait([
        client.api.users.getMe(),
        client.api.users.getMe(),
        client.api.users.getMe(),
      ]);

      expect(users, hasLength(3));
      expect(network.to(_refresh), hasLength(1));
    });

    test('is renewed again the next time it expires', () async {
      await client.api.users.getMe();
      await store.write(stored);

      await client.api.users.getMe();

      expect(network.to(_refresh), hasLength(2));
    });

    test('is not renewed twice for one request', () async {
      network.handler = (request) async => request.path == _refresh
          ? FakeResponse(200, tokenResponse('new-access', 'new-refresh'))
          : FakeResponse.problem(401, AuthInterceptor.expiredTokenCode);

      await expectLater(
        apiCall(() => client.api.users.getMe()),
        throwsA(
          isA<ApiProblem>().having(
            (p) => p.code,
            'code',
            AuthInterceptor.expiredTokenCode,
          ),
        ),
      );
      expect(network.to(_refresh), hasLength(1));
      expect(network.to(_me), hasLength(2));
    });
  });

  group('a session that cannot be renewed', () {
    test('is ended and the app is told', () async {
      network.handler = (request) async => request.path == _refresh
          ? FakeResponse.problem(401, 'auth.refresh_token_invalid')
          : FakeResponse.problem(401, AuthInterceptor.expiredTokenCode);
      final ended = <void>[];
      final subscription = client.sessionEnded.listen(ended.add);
      addTearDown(subscription.cancel);

      await expectLater(
        apiCall(() => client.api.users.getMe()),
        throwsA(isA<ApiProblem>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(await store.read(), isNull);
      expect(await client.hasSession, isFalse);
      expect(ended, hasLength(1));
    });

    test('is kept when the network failed, not the session', () async {
      network.handler = (request) async => request.path == _refresh
          ? throw const FormatException('connection reset')
          : FakeResponse.problem(401, AuthInterceptor.expiredTokenCode);
      final ended = <void>[];
      final subscription = client.sessionEnded.listen(ended.add);
      addTearDown(subscription.cancel);

      await expectLater(
        apiCall(() => client.api.users.getMe()),
        throwsA(isA<ApiProblem>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(await store.read(), stored);
      expect(ended, isEmpty);
    });

    test('is not renewed without a refresh token', () async {
      network.handler = (_) async =>
          FakeResponse.problem(401, AuthInterceptor.expiredTokenCode);
      await store.clear();

      await expectLater(
        apiCall(() => client.api.users.getMe()),
        throwsA(isA<ApiProblem>()),
      );

      expect(network.to(_refresh), isEmpty);
    });
  });

  group('a 401 that is not an expired token', () {
    test('is not renewed', () async {
      network.handler = (_) async =>
          FakeResponse.problem(401, 'auth.session_revoked');

      await expectLater(
        apiCall(() => client.api.users.getMe()),
        throwsA(
          isA<ApiProblem>().having(
            (p) => p.code,
            'code',
            'auth.session_revoked',
          ),
        ),
      );
      expect(network.to(_refresh), isEmpty);
    });

    test('from sign-in is an answer, not an expired session', () async {
      network.handler = (_) async =>
          FakeResponse.problem(401, AuthInterceptor.expiredTokenCode);

      await expectLater(
        apiCall(
          () => client.api.auth.login(
            body: const LoginRequest(
              email: 'ada@example.com',
              password: 'wrong',
            ),
          ),
        ),
        throwsA(isA<ApiProblem>()),
      );
      expect(network.to(_refresh), isEmpty);
      expect(network.to(_login), hasLength(1));
    });
  });

  group('the session', () {
    test('starts from a sign-in response and ends on request', () async {
      await store.clear();
      expect(await client.hasSession, isFalse);

      await client.startSession(
        TokenResponse.fromJson(tokenResponse('access', 'refresh')),
      );
      expect(await client.hasSession, isTrue);
      expect(
        await store.read(),
        const AuthTokens(accessToken: 'access', refreshToken: 'refresh'),
      );

      await client.endSession();
      expect(await client.hasSession, isFalse);
    });
  });
}
