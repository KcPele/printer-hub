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

  return _written(bytes);
}

/// A new identifier for something the app creates before the API hears of
/// it, such as a job started offline: a UUID of version 7, which begins
/// with the time [at].
///
/// The API lists its records by identifier, newest first, so one made here
/// has to sort by when it was made, as the ones the API makes do.
String newRecordId([DateTime? at]) {
  final milliseconds = (at ?? DateTime.now()).millisecondsSinceEpoch;
  final bytes = [
    // 48 bits of time, most significant first. Shifts would overflow where
    // an integer is a 32-bit number.
    for (var place = 5; place >= 0; place--)
      (milliseconds ~/ _powersOf256[place]) % 256,
    for (var i = 0; i < 10; i++) _random.nextInt(256),
  ];
  bytes[6] = (bytes[6] & 0x0f) | 0x70;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  return _written(bytes);
}

const List<int> _powersOf256 = [
  1,
  256,
  65536,
  16777216,
  4294967296,
  1099511627776,
];

String _written(List<int> bytes) {
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
