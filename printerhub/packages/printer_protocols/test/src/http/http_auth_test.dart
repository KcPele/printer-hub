import 'package:printer_protocols/printer_protocols.dart';
import 'package:test/test.dart';

void main() {
  const mufasa = PrinterCredentials(
    userName: 'Mufasa',
    password: 'Circle of Life',
  );
  final page = Uri.parse('http://www.example.org/dir/index.html');

  group('AuthChallenge.parse', () {
    test('reads a Digest challenge', () {
      final challenge = AuthChallenge.parse(
        'Digest realm="Xerox VersaLink", nonce="abc", opaque="xyz", '
        'qop="auth,auth-int", algorithm=SHA-256, stale=TRUE',
      ).single;

      expect(challenge.digest, isTrue);
      expect(challenge.realm, 'Xerox VersaLink');
      expect(challenge.nonce, 'abc');
      expect(challenge.opaque, 'xyz');
      expect(challenge.qop, 'auth');
      expect(challenge.algorithm, 'SHA-256');
      expect(challenge.stale, isTrue);
    });

    test('reads a Basic challenge, with or without a realm', () {
      final named = AuthChallenge.parse('Basic realm="Printer"').single;
      expect(named.digest, isFalse);
      expect(named.realm, 'Printer');
      expect(named.stale, isFalse);

      expect(AuthChallenge.parse('BASIC').single.realm, '');
    });

    test('reads several challenges from one header', () {
      final challenges = AuthChallenge.parse(
        'Basic realm="a, b", Digest realm="c", nonce="n", Negotiate',
      );

      expect(challenges.map((c) => c.digest), [false, true]);
      expect(challenges.first.realm, 'a, b');
      expect(challenges.last.realm, 'c');
      expect(challenges.last.qop, isNull);
    });

    test('leaves out what the app cannot answer', () {
      expect(AuthChallenge.parse(null), isEmpty);
      expect(AuthChallenge.parse('Negotiate'), isEmpty);
      // No nonce to sign with.
      expect(AuthChallenge.parse('Digest realm="x"'), isEmpty);
      // A way of hashing the app does not have.
      expect(
        AuthChallenge.parse('Digest nonce="n", algorithm=SHA-512-256'),
        isEmpty,
      );
    });

    test('prefers Digest, which keeps the password off the wire', () {
      final challenges = AuthChallenge.parse(
        'Basic realm="x", Digest realm="x", nonce="n"',
      );

      expect(AuthChallenge.best(challenges)!.digest, isTrue);
      expect(AuthChallenge.best(AuthChallenge.parse('Basic'))!.digest, isFalse);
      expect(AuthChallenge.best(const []), isNull);
    });
  });

  group('AuthChallenge.authorize', () {
    test('Basic is the name and password in base64', () {
      expect(
        const AuthChallenge(digest: false).authorize(
          const PrinterCredentials(
            userName: 'Aladdin',
            password: 'open sesame',
          ),
          method: 'POST',
          uri: page,
        ),
        'Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==',
      );
    });

    // The worked examples of RFC 7616, section 3.9.1.
    const nonce = '7ypf/xlj9XXwfDPEoM4URrv/xwf94BcCAzFZH4GiTo0v';
    const cnonce = 'f2/wE4q74E6zIJEtWaHKaf5wv/H5QzzpXusqGemxURZJ';
    const opaque = 'FQhe/qaU925kfnzjCev0ciny7QMkPqMAFRtzCUYo5tdS';

    test("Digest with MD5 matches the standard's example", () {
      final header = const AuthChallenge(
        digest: true,
        realm: 'http-auth@example.org',
        nonce: nonce,
        opaque: opaque,
        algorithm: 'MD5',
        qop: 'auth',
      ).authorize(mufasa, method: 'GET', uri: page, clientNonce: cnonce);

      expect(header, startsWith('Digest username="Mufasa"'));
      expect(header, contains('response="8ca523f5e9506fed4657c9700eebdbec"'));
      expect(header, contains('uri="/dir/index.html"'));
      expect(header, contains('qop=auth, nc=00000001, cnonce="$cnonce"'));
      expect(header, contains('algorithm=MD5'));
      expect(header, contains('opaque="$opaque"'));
    });

    test("Digest with SHA-256 matches the standard's example", () {
      final header = const AuthChallenge(
        digest: true,
        realm: 'http-auth@example.org',
        nonce: nonce,
        algorithm: 'SHA-256',
        qop: 'auth',
      ).authorize(mufasa, method: 'GET', uri: page, clientNonce: cnonce);

      expect(
        header,
        contains(
          'response="753927fa0e85d155564e2e272a28d180'
          '2ca10daf4496794697cf8db5856cb6c1"',
        ),
      );
      expect(header, isNot(contains('opaque')));
    });

    test('answers the older form, which has no counter', () {
      final header =
          const AuthChallenge(
            digest: true,
            realm: 'Old',
            nonce: 'n1',
          ).authorize(
            const PrinterCredentials(userName: 'ada', password: 's3cret'),
            method: 'POST',
            uri: Uri.parse('http://printer/ipp/print?a=1'),
          );

      expect(header, contains('uri="/ipp/print?a=1"'));
      expect(header, contains('response="71448e759c5da1a00a27f58f1eea8302"'));
      expect(header, isNot(contains('qop')));
      expect(header, isNot(contains('algorithm')));
    });

    test('counts each use, and makes its own nonce for each', () {
      const challenge = AuthChallenge(digest: true, nonce: 'n', qop: 'auth');
      String sign(int count) =>
          challenge.authorize(mufasa, method: 'POST', uri: page, count: count);
      String cnonceOf(String header) =>
          RegExp('cnonce="([0-9a-f]{32})"').firstMatch(header)!.group(1)!;

      expect(sign(1), contains('nc=00000001'));
      expect(sign(26), contains('nc=0000001a'));
      expect(cnonceOf(sign(1)), isNot(cnonceOf(sign(1))));
    });
  });
}
