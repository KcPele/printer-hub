import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_store/local_store.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorage extends Mock implements FlutterSecureStorage;

void main() {
  group('KeystoreSecureStore', () {
    late _MockStorage storage;
    late KeystoreSecureStore store;

    setUp(() {
      storage = _MockStorage();
      store = KeystoreSecureStore(storage: storage);
    });

    test('reads from the keystore', () async {
      when(() => storage.read(key: 'k')).thenAnswer((_) async => 'v');

      expect(await store.read('k'), 'v');
    });

    test('writes to the keystore', () async {
      when(() => storage.write(key: 'k', value: 'v')).thenAnswer((_) async {});

      await store.write('k', 'v');

      verify(() => storage.write(key: 'k', value: 'v')).called(1);
    });

    test('deletes from the keystore', () async {
      when(() => storage.delete(key: 'k')).thenAnswer((_) async {});

      await store.delete('k');

      verify(() => storage.delete(key: 'k')).called(1);
    });

    test('uses the platform keystore by default', () {
      expect(const KeystoreSecureStore(), isA<SecureStore>());
    });
  });

  group('InMemorySecureStore', () {
    test('reads, writes, and deletes', () async {
      final store = InMemorySecureStore({'a': '1'});

      expect(await store.read('a'), '1');
      expect(await store.read('b'), isNull);

      await store.write('b', '2');
      expect(await store.read('b'), '2');

      await store.delete('a');
      expect(await store.read('a'), isNull);
      expect(store.values, {'b': '2'});
    });
  });
}
