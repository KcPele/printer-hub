import 'package:equatable/equatable.dart';

/// Opens a link in the phone's browser, or whichever app takes it.
// One member, but a class so the app can be given a stand-in for it.
abstract interface class LinkOpener {
  /// True when something on the phone opened [link].
  Future<bool> open(Uri link);
}

/// What a code read by the camera turned out to be.
enum CodeKind { link, wifi, text }

/// A QR code or barcode that was read, and what it says.
class ReadCode extends Equatable {
  const new _({
    required this.text,
    required this.kind,
    this.link,
    this.network = '',
    this.password = '',
  });

  /// Makes sense of what a code says.
  factory read(String text) {
    final trimmed = text.trim();
    if (trimmed.toUpperCase().startsWith('WIFI:')) {
      final fields = _wifiFields(trimmed.substring(5));
      final network = fields['S'];
      if (network != null && network.isNotEmpty) {
        return ReadCode._(
          text: trimmed,
          kind: CodeKind.wifi,
          network: network,
          password: fields['P'] ?? '',
        );
      }
    }
    final link = Uri.tryParse(trimmed);
    if (link != null &&
        (link.scheme == 'http' || link.scheme == 'https') &&
        link.host.isNotEmpty) {
      return ReadCode._(text: trimmed, kind: CodeKind.link, link: link);
    }
    return ReadCode._(text: trimmed, kind: CodeKind.text);
  }

  /// Everything the code says.
  final String text;
  final CodeKind kind;

  /// Where it leads, for a [CodeKind.link].
  final Uri? link;

  /// The network's name and password, for a [CodeKind.wifi]. An open
  /// network has no password.
  final String network;
  final String password;

  @override
  List<Object?> get props => [text];
}

/// The fields of a Wi-Fi code, `T:WPA;S:name;P:secret;;`, by their
/// letter. A `;`, `:`, `,`, `"` or `\` inside a value has a `\` before it.
Map<String, String> _wifiFields(String body) {
  final fields = <String, String>{};
  final field = StringBuffer();
  void end() {
    final text = field.toString();
    field.clear();
    final colon = text.indexOf(':');
    if (colon > 0) {
      fields[text.substring(0, colon).toUpperCase()] = text
          .substring(colon + 1)
          .replaceAllMapped(RegExp(r'\\(.)'), (match) => match[1]!);
    }
  }

  for (var i = 0; i < body.length; i++) {
    final char = body[i];
    if (char == r'\' && i + 1 < body.length) {
      field
        ..write(char)
        ..write(body[++i]);
    } else if (char == ';') {
      end();
    } else {
      field.write(char);
    }
  }
  end();
  return fields;
}
