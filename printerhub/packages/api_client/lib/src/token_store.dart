import 'package:meta/meta.dart';

/// The pair of tokens a session holds.
@immutable
class AuthTokens {
  const new({required this.accessToken, required this.refreshToken});

  /// Short-lived. Sent with every request.
  final String accessToken;

  /// Long-lived and single-use. Exchanged for a new pair when the access
  /// token expires.
  final String refreshToken;

  @override
  bool operator ==(Object other) {
    return other is AuthTokens &&
        other.accessToken == accessToken &&
        other.refreshToken == refreshToken;
  }

  @override
  int get hashCode => Object.hash(accessToken, refreshToken);
}

/// Where the session's tokens are kept.
///
/// The app keeps them in the platform keystore. This package stays free of
/// Flutter plugins, so it only defines the contract.
abstract interface class TokenStore {
  Future<AuthTokens?> read();

  Future<void> write(AuthTokens tokens);

  Future<void> clear();
}

/// Keeps tokens in memory. For tests and for tools without a keystore.
class InMemoryTokenStore implements TokenStore {
  new([this._tokens]);

  AuthTokens? _tokens;

  @override
  Future<AuthTokens?> read() async => _tokens;

  @override
  Future<void> write(AuthTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}
