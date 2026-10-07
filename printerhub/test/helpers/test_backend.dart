import 'dart:convert';

import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:local_store/local_store.dart';
import 'package:organizations_repository/organizations_repository.dart';

/// A pretend PrinterHub API with the real client and repositories on top,
/// so a test exercises everything from the screen down to the request.
///
/// It behaves like a healthy backend for one user. Change [user] and
/// [organizations] to set the scene, put a handler in [routes] to make one
/// endpoint misbehave, or set [offline].
class TestBackend {
  new() {
    network = FakeApi(_answer);
    client = PrinterHubClient(
      baseUrl: Uri.parse('https://api.example.com'),
      tokenStore: SecureTokenStore(store),
      httpClientAdapter: network,
    );
    auth = AuthRepository(client: client, store: store);
    organizations = OrganizationsRepository(client: client, store: store);
  }

  final InMemorySecureStore store = InMemorySecureStore();
  late final FakeApi network;
  late final PrinterHubClient client;
  late final AuthRepository auth;
  late final OrganizationsRepository organizations;

  /// The account the API knows.
  Map<String, Object?> user = userBody();

  /// The workspaces that account belongs to.
  List<Map<String, Object?>> workspaces = [];

  /// Handlers by `'METHOD /path'`, without the `/api/v1` prefix. They take
  /// the place of the default answer.
  final Map<String, FakeHandler> routes = {};

  /// When true every request fails as if there were no connection.
  bool offline = false;

  /// The requests sent to `'METHOD /path'`.
  List<RequestOptions> sent(String route) {
    return network.requests.where((request) => _key(request) == route).toList();
  }

  /// The JSON body of the last request to `'METHOD /path'`.
  Map<String, dynamic> lastBody(String route) {
    return jsonDecode(jsonEncode(sent(route).last.data))
        as Map<String, dynamic>;
  }

  /// Makes one endpoint answer with an API error.
  void fail(String route, int status, String code, {String? detail}) {
    routes[route] = (_) async =>
        FakeResponse.problem(status, code, detail: detail);
  }

  /// Puts a session from an earlier launch on the device, as bootstrap
  /// would find it.
  ///
  /// Inside `testWidgets`, call it through `tester.runAsync`, or from
  /// `setUp`: a request awaited directly under the fake clock never ends.
  Future<void> signedInBefore({bool withWorkspace = true}) async {
    if (withWorkspace && workspaces.isEmpty) workspaces = [organizationBody()];
    await auth.signIn(email: 'ada@example.com', password: 'correct horse');
    if (workspaces.isNotEmpty) await organizations.list();
    network.requests.clear();
  }

  Future<void> close() async {
    await auth.close();
    await client.close();
  }

  static String _key(RequestOptions request) {
    return '${request.method} ${request.path.replaceFirst('/api/v1', '')}';
  }

  Future<FakeResponse> _answer(RequestOptions request) async {
    if (offline) throw const FormatException('offline');

    final key = _key(request);
    final custom = routes[key];
    if (custom != null) return await custom(request);

    final body = request.data is Map
        ? jsonDecode(jsonEncode(request.data)) as Map<String, dynamic>
        : const <String, dynamic>{};
    final session = {
      'user': user,
      'tokens': tokenResponse('access', 'refresh'),
    };

    switch (key) {
      case 'POST /auth/login':
        return FakeResponse(200, session);
      case 'POST /auth/register':
        user = {...user, 'name': body['name'], 'email': body['email']};
        return FakeResponse(201, {...session, 'user': user});
      case 'GET /users/me':
        return FakeResponse(200, user);
      case 'PATCH /users/me':
        user = {
          ...user,
          if (body['name'] != null) 'name': body['name'],
          if (body['preferences'] != null)
            'preferences': {
              ...user['preferences']! as Map<String, Object?>,
              ...body['preferences'] as Map<String, dynamic>,
            },
        };
        return FakeResponse(200, user);
      case 'POST /auth/email/verify':
        user = {...user, 'email_verified_at': '2026-10-07T11:00:00Z'};
        return FakeResponse(200, user);
      case 'GET /organizations':
        return FakeResponse(200, workspaces);
      case 'POST /organizations':
        final created = organizationBody(
          id: 'org-${workspaces.length + 1}',
          name: body['name'] as String,
        );
        workspaces = [...workspaces, created];
        return FakeResponse(201, created);
      case 'POST /auth/logout' ||
          'POST /auth/email/resend' ||
          'POST /auth/password/forgot' ||
          'POST /auth/password/reset' ||
          'POST /auth/password/change' ||
          'POST /account/delete':
        return const FakeResponse(204);
    }
    return FakeResponse.problem(404, 'not_found', detail: 'No route for $key');
  }
}
