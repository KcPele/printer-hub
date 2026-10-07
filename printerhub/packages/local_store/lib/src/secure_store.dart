import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small values that must not be readable by other apps: tokens, the signed-in
/// user, this install's identifier.
abstract interface class SecureStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// Keeps values in the Keychain on iOS and the Keystore on Android.
class KeystoreSecureStore implements SecureStore {
  const new({this._storage = const FlutterSecureStorage()});

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Keeps values in memory. For tests.
class InMemorySecureStore implements SecureStore {
  new([Map<String, String>? values]) : values = {...?values};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
