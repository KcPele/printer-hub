import 'dart:convert';

import 'package:equatable/equatable.dart';

/// What a QR code or an NFC tag turned out to hold.
sealed class ScannedCode extends Equatable {
  const new();

  /// Reads the text of a QR code or NFC record.
  ///
  /// Printers and PrinterHub itself put several kinds of thing in a code:
  /// a pairing code, the printer's address, or the name and password of the
  /// printer's own Wi-Fi network.
  factory parse(String raw) {
    final text = raw.trim();
    return _pairing(text) ??
        _wifi(text) ??
        _address(text) ??
        UnrecognisedCode(text);
  }
}

/// A PrinterHub pairing code, made on another member's phone. It names a
/// printer in a workspace; it is short-lived and carries no password.
final class PairingCode extends ScannedCode {
  const new({required this.token, this.printerId, this.organizationId});

  final String token;
  final String? printerId;
  final String? organizationId;

  @override
  List<Object?> get props => [token, printerId, organizationId];
}

/// Where a printer answers: an IP address, a host name, or a full
/// `ipp://` or `http://` address.
final class PrinterAddressCode extends ScannedCode {
  const new(this.address);

  final String address;

  @override
  List<Object?> get props => [address];
}

/// The printer's own Wi-Fi network (Wi-Fi Direct), to join before the
/// printer can be reached.
final class WifiNetworkCode extends ScannedCode {
  const new({required this.ssid, this.password});

  final String ssid;
  final String? password;

  @override
  List<Object?> get props => [ssid, password];
}

/// Something else: a web link, a serial number, a code for another app.
final class UnrecognisedCode extends ScannedCode {
  const new(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

ScannedCode? _pairing(String text) {
  // As JSON: {"v":1,"token":"…","printer_id":"…","organization_id":"…"}
  if (text.startsWith('{')) {
    try {
      final json = jsonDecode(text);
      if (json is Map<String, dynamic> && json['token'] is String) {
        return PairingCode(
          token: json['token'] as String,
          printerId: json['printer_id'] as String?,
          organizationId: json['organization_id'] as String?,
        );
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  // As a link: printerhub://pair?token=…&printer_id=…&organization_id=…
  final uri = Uri.tryParse(text);
  if (uri == null || uri.scheme != 'printerhub') return null;
  final token = uri.queryParameters['token'];
  if (token == null || token.isEmpty) return null;
  return PairingCode(
    token: token,
    printerId: uri.queryParameters['printer_id'],
    organizationId: uri.queryParameters['organization_id'],
  );
}

/// The format phones and printers use for a Wi-Fi network:
/// `WIFI:T:WPA;S:DIRECT-AB-Printer;P:secret;;`. A `;`, `:`, `,`, or `\`
/// inside a value is written with a backslash before it.
ScannedCode? _wifi(String text) {
  if (!text.toUpperCase().startsWith('WIFI:')) return null;

  final fields = <String, String>{};
  final buffer = StringBuffer();
  String? key;
  final body = text.substring(5);
  for (var i = 0; i < body.length; i++) {
    final char = body[i];
    if (char == r'\' && i + 1 < body.length) {
      buffer.write(body[++i]);
    } else if (char == ':' && key == null) {
      key = buffer.toString().toUpperCase();
      buffer.clear();
    } else if (char == ';') {
      if (key != null) fields[key] = buffer.toString();
      key = null;
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }

  final ssid = fields['S'];
  if (ssid == null || ssid.isEmpty) return null;
  final password = fields['P'];
  return WifiNetworkCode(
    ssid: ssid,
    password: password == null || password.isEmpty ? null : password,
  );
}

final RegExp _host = RegExp(
  r'^[a-zA-Z0-9]([a-zA-Z0-9\-\.]*[a-zA-Z0-9])?(:\d{1,5})?$',
);

ScannedCode? _address(String text) {
  final uri = Uri.tryParse(text);
  if (uri != null &&
      const {'ipp', 'ipps', 'http', 'https'}.contains(uri.scheme) &&
      uri.host.isNotEmpty) {
    return PrinterAddressCode(text);
  }
  // A bare address needs a dot or a port, or any single word would pass.
  if (_host.hasMatch(text) && (text.contains('.') || text.contains(':'))) {
    return PrinterAddressCode(text);
  }
  return null;
}
