import 'package:api_client/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_store/local_store.dart';

void main() {
  group('SecureTokenStore', () {
    const tokens = AuthTokens(accessToken: 'access', refreshToken: 'refresh');
    late InMemorySecureStore secure;
    late SecureTokenStore store;

    setUp(() {
      secure = InMemorySecureStore();
      store = SecureTokenStore(secure);
    });

    test('has no tokens on a new install', () async {
      expect(await store.read(), isNull);
    });

    test('keeps the tokens for the next launch', () async {
      await store.write(tokens);

      expect(await SecureTokenStore(secure).read(), tokens);
    });

    test('has no session when half of the pair is missing', () async {
      await store.write(tokens);
      await secure.delete('session.refresh_token');

      expect(await store.read(), isNull);
    });

    test('forgets the tokens', () async {
      await store.write(tokens);

      await store.clear();

      expect(await store.read(), isNull);
      expect(secure.values, isEmpty);
    });
  });
}
