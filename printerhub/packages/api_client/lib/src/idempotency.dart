import 'dart:math';

final Random _random = Random.secure();

/// A new value for the `Idempotency-Key` header: a random UUID (version 4).
///
/// Make one per logical operation and save it with the operation before the
/// first attempt. Sending the same key again returns the first result instead
/// of creating a second job.
String newIdempotencyKey() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
