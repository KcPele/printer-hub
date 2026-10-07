import 'package:api_client/api_client.dart';
import 'package:local_store/src/secure_store.dart';

/// Keeps the session's tokens in a [SecureStore].
class SecureTokenStore implements TokenStore {
  const new(this._store);

  static const String _accessKey = 'session.access_token';
  static const String _refreshKey = 'session.refresh_token';

  final SecureStore _store;

  @override
  Future<AuthTokens?> read() async {
    final access = await _store.read(_accessKey);
    final refresh = await _store.read(_refreshKey);
    if (access == null || refresh == null) return null;
    return AuthTokens(accessToken: access, refreshToken: refresh);
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    await _store.write(_accessKey, tokens.accessToken);
    await _store.write(_refreshKey, tokens.refreshToken);
  }

  @override
  Future<void> clear() async {
    await _store.delete(_accessKey);
    await _store.delete(_refreshKey);
  }
}
