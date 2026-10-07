import 'package:api_client/api_client.dart';
import 'package:test/test.dart';

void main() {
  group('newIdempotencyKey', () {
    final uuidV4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    test('is a version 4 UUID', () {
      for (var i = 0; i < 100; i++) {
        expect(newIdempotencyKey(), matches(uuidV4));
      }
    });

    test('is different every time', () {
      final keys = {for (var i = 0; i < 1000; i++) newIdempotencyKey()};

      expect(keys, hasLength(1000));
    });
  });
}
