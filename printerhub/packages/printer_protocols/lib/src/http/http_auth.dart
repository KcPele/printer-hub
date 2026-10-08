import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

/// The user name and password a printer asks for.
@immutable
class PrinterCredentials {
  const new({required this.userName, required this.password});

  final String userName;
  final String password;
}

/// How a device asked to be signed in to, from its `WWW-Authenticate`
/// header.
@immutable
class AuthChallenge {
  const new({
    required this.digest,
    this.realm = '',
    this.nonce,
    this.opaque,
    this.algorithm,
    this.qop,
    this.stale = false,
  });

  /// True for Digest, which never sends the password. False for Basic,
  /// which sends it as good as in the clear.
  final bool digest;
  final String realm;
  final String? nonce;
  final String? opaque;

  /// `MD5` when the device does not say.
  final String? algorithm;

  /// `auth` when the device offers it, else null for the older form.
  final String? qop;

  /// True when the device accepted the password but wants the request
  /// signed again with the new [nonce].
  final bool stale;

  /// The challenges in a `WWW-Authenticate` header. A device may offer
  /// several ways in one header; ways the app does not speak are left out.
  static List<AuthChallenge> parse(String? header) {
    if (header == null) return const [];
    final starts = _scheme.allMatches(header).toList();
    return [
      for (var i = 0; i < starts.length; i++)
        ?_one(
          starts[i].group(1)!.toLowerCase(),
          header.substring(
            starts[i].end,
            i + 1 < starts.length ? starts[i + 1].start : header.length,
          ),
        ),
    ];
  }

  /// The best of [challenges]: Digest before Basic. Null when there is
  /// none.
  static AuthChallenge? best(List<AuthChallenge> challenges) {
    for (final challenge in challenges) {
      if (challenge.digest) return challenge;
    }
    return challenges.firstOrNull;
  }

  static final RegExp _scheme = RegExp(
    r'(?:^|,)\s*(basic|digest)(?=\s|$)',
    caseSensitive: false,
  );
  static final RegExp _parameter = RegExp(
    r'([a-zA-Z-]+)\s*=\s*(?:"((?:[^"\\]|\\.)*)"|([^,\s]+))',
  );

  static AuthChallenge? _one(String scheme, String rest) {
    final values = {
      for (final match in _parameter.allMatches(rest))
        match.group(1)!.toLowerCase(): match.group(2) ?? match.group(3)!,
    };
    if (scheme == 'basic') {
      return AuthChallenge(digest: false, realm: values['realm'] ?? '');
    }
    final algorithm = values['algorithm'];
    final supported =
        algorithm == null ||
        const {'MD5', 'SHA-256'}.contains(algorithm.toUpperCase());
    if (values['nonce'] == null || !supported) return null;
    final qop = (values['qop'] ?? '')
        .split(',')
        .map((option) => option.trim())
        .contains('auth');
    return AuthChallenge(
      digest: true,
      realm: values['realm'] ?? '',
      nonce: values['nonce'],
      opaque: values['opaque'],
      algorithm: algorithm,
      qop: qop ? 'auth' : null,
      stale: values['stale']?.toLowerCase() == 'true',
    );
  }

  /// The `Authorization` header that answers this challenge for one
  /// request. [count] is how many requests have used this challenge, from
  /// 1; a device refuses a count it has seen.
  String authorize(
    PrinterCredentials credentials, {
    required String method,
    required Uri uri,
    int count = 1,
    String? clientNonce,
  }) {
    if (!digest) {
      final pair = '${credentials.userName}:${credentials.password}';
      return 'Basic ${base64.encode(utf8.encode(pair))}';
    }

    String hash(String text) {
      final bytes = utf8.encode(text);
      return algorithm?.toUpperCase() == 'SHA-256'
          ? sha256.convert(bytes).toString()
          : md5.convert(bytes).toString();
    }

    final path = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
    final user = hash('${credentials.userName}:$realm:${credentials.password}');
    final request = hash('$method:$path');
    final fields = <String, String>{
      'username': '"${credentials.userName}"',
      'realm': '"$realm"',
      'nonce': '"$nonce"',
      'uri': '"$path"',
    };
    if (qop == null) {
      fields['response'] = '"${hash('$user:$nonce:$request')}"';
    } else {
      final cnonce = clientNonce ?? _randomNonce();
      final nc = count.toRadixString(16).padLeft(8, '0');
      fields['qop'] = 'auth';
      fields['nc'] = nc;
      fields['cnonce'] = '"$cnonce"';
      fields['response'] =
          '"${hash('$user:$nonce:$nc:$cnonce:auth:$request')}"';
    }
    if (algorithm != null) fields['algorithm'] = algorithm!;
    if (opaque != null) fields['opaque'] = '"$opaque"';
    final listed = fields.entries.map((f) => '${f.key}=${f.value}');
    return 'Digest ${listed.join(', ')}';
  }

  static String _randomNonce() {
    final random = Random.secure();
    return [
      for (var i = 0; i < 16; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }
}
