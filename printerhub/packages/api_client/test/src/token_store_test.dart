import 'package:api_client/api_client.dart';
import 'package:test/test.dart';

void main() {
  const tokens = AuthTokens(accessToken: 'access', refreshToken: 'refresh');

  group('AuthTokens', () {
    test('are equal when both tokens match', () {
      const same = AuthTokens(accessToken: 'access', refreshToken: 'refresh');
      const other = AuthTokens(accessToken: 'access', refreshToken: 'other');

      expect(tokens, same);
      expect(tokens.hashCode, same.hashCode);
      expect(tokens, isNot(other));
    });
  });

  group('InMemoryTokenStore', () {
    test('starts empty unless given tokens', () async {
      expect(await InMemoryTokenStore().read(), isNull);
      expect(await InMemoryTokenStore(tokens).read(), tokens);
    });

    test('writes and clears', () async {
      final store = InMemoryTokenStore();

      await store.write(tokens);
      expect(await store.read(), tokens);

      await store.clear();
      expect(await store.read(), isNull);
    });
  });
}
