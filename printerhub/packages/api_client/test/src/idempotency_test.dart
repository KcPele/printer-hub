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

  group('newRecordId', () {
    final uuidV7 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    test('is a version 7 UUID', () {
      for (var i = 0; i < 100; i++) {
        expect(newRecordId(), matches(uuidV7));
      }
    });

    test('begins with the time it was made at', () {
      final id = newRecordId(DateTime.utc(2026, 10, 8, 9, 30));

      // 1791451800000 milliseconds, as twelve hexadecimal digits.
      expect(id.replaceAll('-', '').substring(0, 12), '01a11ad921c0');
      expect(id, matches(uuidV7));
    });

    test('sorts by when it was made', () {
      final earlier = newRecordId(DateTime.utc(2026, 10, 8, 9, 30));
      final later = newRecordId(DateTime.utc(2026, 10, 8, 9, 30, 0, 1));

      expect(earlier.compareTo(later), isNegative);
    });

    test('is different every time, at the same moment', () {
      final at = DateTime.utc(2026, 10, 8);
      final ids = {for (var i = 0; i < 1000; i++) newRecordId(at)};

      expect(ids, hasLength(1000));
    });
  });
}
