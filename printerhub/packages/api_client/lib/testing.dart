// Test support is not part of what the package ships to users.
// coverage:ignore-file

/// A stand-in for the network, for tests of anything built on the client.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// What the fake API answers with.
class FakeResponse {
  const new(this.status, [this.body]);

  /// An `application/problem+json` error, as the API sends them.
  new problem(this.status, String code, {String? detail})
    : body = {
        'type': 'about:blank',
        'title': 'Error',
        'status': status,
        'code': code,
        'detail': detail,
        'request_id': 'req-1',
        'errors': null,
      };

  final int status;
  final Object? body;

  bool get isProblem =>
      status >= 400 && body is Map && (body! as Map)['code'] != null;
}

typedef FakeHandler = Future<FakeResponse> Function(RequestOptions request);

/// Stands in for the network. Records every request and answers from
/// [handler].
class FakeApi implements HttpClientAdapter {
  new(this.handler);

  FakeHandler handler;
  final List<RequestOptions> requests = [];

  /// The requests sent to [path], in order.
  List<RequestOptions> to(String path) =>
      requests.where((request) => request.path == path).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = await handler(options);
    return ResponseBody.fromString(
      response.body == null ? '' : jsonEncode(response.body),
      response.status,
      headers: {
        Headers.contentTypeHeader: [
          if (response.isProblem)
            'application/problem+json'
          else
            'application/json',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A `TokenResponse` body.
Map<String, Object?> tokenResponse(String access, String refresh) => {
  'access_token': access,
  'refresh_token': refresh,
  'token_type': 'bearer',
  'expires_in': 900,
  'session_id': '0198c0de-0000-7000-8000-000000000001',
};

/// A `UserRead` body.
Map<String, Object?> userBody({String email = 'ada@example.com'}) => {
  'id': '0198c0de-0000-7000-8000-000000000002',
  'email': email,
  'email_verified_at': null,
  'name': 'Ada',
  'preferences': {
    'theme': 'system',
    'app_theme': 'mint',
    'default_organization_id': null,
    'default_printer_id': null,
    'muted_notification_types': <String>[],
  },
  'is_superuser': false,
  'created_at': '2026-10-07T10:00:00Z',
};

/// An `OrganizationRead` body.
Map<String, Object?> organizationBody({
  String id = '0198c0de-0000-7000-8000-00000000000b',
  String name = 'Acme',
  String role = 'owner',
}) => {
  'id': id,
  'name': name,
  'slug': name.toLowerCase(),
  'role': role,
  'settings': {
    'color_printing_roles': ['owner', 'admin', 'operator', 'user'],
    'document_retention_days': null,
    'document_storage_mode': 'cloud_allowed',
    'max_copies_per_job': null,
  },
  'created_at': '2026-10-07T10:00:00Z',
};
