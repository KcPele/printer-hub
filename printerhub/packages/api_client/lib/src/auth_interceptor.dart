import 'dart:async';

import 'package:api_client/src/api_exception.dart';
import 'package:api_client/src/generated/export.dart';
import 'package:api_client/src/token_store.dart';
import 'package:dio/dio.dart';

/// Sends the access token with each request and renews it when it expires.
///
/// When the API answers 401 with `auth.token_expired`, the refresh token is
/// exchanged for a new pair and the request is sent again, once. The API
/// revokes a session whose refresh token is used twice, so requests that
/// expire together share a single refresh.
///
/// When the session cannot be renewed the tokens are cleared and
/// `onSessionEnded` is called, so the app can return to sign-in.
class AuthInterceptor extends Interceptor {
  new({
    required this._tokenStore,
    required this._refreshDio,
    required this._retryDio,
    this._onSessionEnded,
  });

  static const String expiredTokenCode = 'auth.token_expired';

  /// Requests made without a session. They carry no token, and a 401 from
  /// them is an answer, not an expired session.
  static const Set<String> sessionlessPaths = {
    '/api/v1/auth/login',
    '/api/v1/auth/register',
    '/api/v1/auth/refresh',
    '/api/v1/auth/password/forgot',
    '/api/v1/auth/password/reset',
  };

  static const String _retried = 'auth_retried';

  final TokenStore _tokenStore;
  final Dio _refreshDio;
  final Dio _retryDio;
  final void Function()? _onSessionEnded;

  Future<AuthTokens?>? _refreshing;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!sessionlessPaths.contains(options.path)) {
      final tokens = await _tokenStore.read();
      if (tokens != null) {
        options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final response = err.response;
    final expired =
        response != null &&
        response.statusCode == 401 &&
        ApiProblem.fromResponse(response).code == expiredTokenCode;

    if (!expired ||
        sessionlessPaths.contains(request.path) ||
        request.extra[_retried] == true) {
      return handler.next(err);
    }

    final tokens = await _refreshOnce();
    if (tokens == null) return handler.next(err);

    try {
      final retry = await _retryDio.fetch<dynamic>(
        request.copyWith(
          headers: {
            ...request.headers,
            'Authorization': 'Bearer ${tokens.accessToken}',
          },
          extra: {...request.extra, _retried: true},
        ),
      );
      handler.resolve(retry);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<AuthTokens?> _refreshOnce() {
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<AuthTokens?> _refresh() async {
    final current = await _tokenStore.read();
    if (current == null) return null;

    try {
      final renewed = await AuthClient(_refreshDio)
          .refresh(body: RefreshRequest(refreshToken: current.refreshToken));
      final tokens = AuthTokens(
        accessToken: renewed.accessToken,
        refreshToken: renewed.refreshToken,
      );
      await _tokenStore.write(tokens);
      return tokens;
    } on DioException catch (error) {
      // No answer means the network failed, not the session: keep the
      // tokens so the next request can try again.
      if (error.response == null) return null;
      await _tokenStore.clear();
      _onSessionEnded?.call();
      return null;
    }
  }
}
