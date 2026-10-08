import 'dart:convert';

/// The prefixes an NFC "URI" record abbreviates to one byte.
const List<String> _uriPrefixes = [
  '',
  'http://www.',
  'https://www.',
  'http://',
  'https://',
  'tel:',
  'mailto:',
];

/// The readable content of one NDEF record, or null when it holds none.
///
/// [type] is the record's type as text: `U` for a link and `T` for text
/// among the well-known types, or a MIME type such as
/// `application/vnd.wfa.wsc` for a Wi-Fi network.
String? textOfNdefRecord({required String type, required List<int> payload}) {
  if (payload.isEmpty) return null;

  switch (type) {
    case 'U':
      final code = payload.first;
      final prefix = code < _uriPrefixes.length ? _uriPrefixes[code] : '';
      return prefix + utf8.decode(payload.sublist(1), allowMalformed: true);
    case 'T':
      // The first byte holds the length of the language code that follows.
      final skip = 1 + (payload.first & 0x3F);
      if (skip > payload.length) return null;
      return utf8.decode(payload.sublist(skip), allowMalformed: true);
    case 'application/vnd.wfa.wsc':
      return _wifiFromHandover(payload);
  }
  // Anything else that is plain text is worth trying to read as a code.
  if (type.startsWith('text/') || type == 'application/json') {
    return utf8.decode(payload, allowMalformed: true);
  }
  return null;
}

/// Reads the network name and key from a Wi-Fi Simple Configuration record,
/// which is how a printer's NFC tag hands over its own Wi-Fi network. The
/// answer is in the same `WIFI:` form a QR code uses.
String? _wifiFromHandover(List<int> payload) {
  const ssidId = 0x1045;
  const keyId = 0x1027;
  const credentialId = 0x100E;

  String? ssid;
  String? key;

  void read(List<int> bytes) {
    var at = 0;
    while (at + 4 <= bytes.length) {
      final id = (bytes[at] << 8) | bytes[at + 1];
      final length = (bytes[at + 2] << 8) | bytes[at + 3];
      final end = at + 4 + length;
      if (end > bytes.length) return;
      final value = bytes.sublist(at + 4, end);
      if (id == credentialId) {
        read(value);
      } else if (id == ssidId) {
        ssid = utf8.decode(value, allowMalformed: true);
      } else if (id == keyId) {
        key = utf8.decode(value, allowMalformed: true);
      }
      at = end;
    }
  }

  read(payload);
  if (ssid == null || ssid!.isEmpty) return null;

  String escape(String value) =>
      value.replaceAllMapped(RegExp(r'([\;,:"])'), (m) => '\\${m[1]}');
  final password = key == null || key!.isEmpty ? '' : 'P:${escape(key!)};';
  return 'WIFI:T:WPA;S:${escape(ssid!)};$password;';
}
