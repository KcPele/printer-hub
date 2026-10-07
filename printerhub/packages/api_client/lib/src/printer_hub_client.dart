import 'dart:async';

import 'package:api_client/src/auth_interceptor.dart';
import 'package:api_client/src/generated/export.dart';
import 'package:api_client/src/token_store.dart';
import 'package:dio/dio.dart';

/// The PrinterHub API, ready to call.
///
/// [api] has one client per area (`api.auth`, `api.printers`, `api.jobs`).
/// Wrap a call in `apiCall` to receive failures as an `ApiException`.
class PrinterHubClient {
  /// Connects to the API at [baseUrl], for example
  /// `https://printerhub-backend.kcpele.com`.
  ///
  /// [httpClientAdapter] replaces the network in tests.
  factory({
    required Uri baseUrl,
    required TokenStore tokenStore,
    HttpClientAdapter? httpClientAdapter,
    Duration connectTimeout = const Duration(seconds: 10),
    Duration receiveTimeout = const Duration(seconds: 30),
  }) {
    final options = BaseOptions(
      baseUrl: baseUrl.toString().replaceFirst(RegExp(r'/+$'), ''),
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      headers: {'Accept': 'application/json, application/problem+json'},
    );

    Dio newDio() {
      final dio = Dio(options);
      if (httpClientAdapter != null) dio.httpClientAdapter = httpClientAdapter;
      return dio;
    }

    final sessionEnded = StreamController<void>.broadcast();
    // Refreshing and retrying go through clients without the interceptor, so
    // a failure there is never refreshed or retried again.
    final dio = newDio();
    dio.interceptors.add(
      AuthInterceptor(
        tokenStore: tokenStore,
        refreshDio: newDio(),
        retryDio: newDio(),
        onSessionEnded: () => sessionEnded.add(null),
      ),
    );

    return PrinterHubClient._(PrinterHubApi(dio), tokenStore, sessionEnded);
  }

  new _(this.api, this._tokenStore, this._sessionEnded);

  final PrinterHubApi api;
  final TokenStore _tokenStore;
  final StreamController<void> _sessionEnded;

  /// Fires when the session could not be renewed and its tokens were
  /// cleared. The app returns to sign-in.
  Stream<void> get sessionEnded => _sessionEnded.stream;

  /// Whether tokens are stored. They may still turn out to be revoked.
  Future<bool> get hasSession async => await _tokenStore.read() != null;

  /// Saves the tokens from a sign-in or registration response.
  Future<void> startSession(TokenResponse tokens) {
    return _tokenStore.write(
      AuthTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      ),
    );
  }

  /// Forgets the tokens on this device. Call `api.auth.logout()` first to
  /// revoke the session on the server.
  Future<void> endSession() => _tokenStore.clear();

  Future<void> close() => _sessionEnded.close();
}
