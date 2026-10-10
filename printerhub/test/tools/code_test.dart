import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/tools/tools.dart';

void main() {
  group('ReadCode', () {
    test('knows a link', () {
      final code = ReadCode.read(' https://example.com/menu?table=4 ');

      expect(code.kind, CodeKind.link);
      expect(code.link, Uri.parse('https://example.com/menu?table=4'));
      expect(code.text, 'https://example.com/menu?table=4');
      expect(ReadCode.read('http://printer.local').kind, CodeKind.link);
    });

    test('takes anything else as words', () {
      for (final text in [
        '5901234123457',
        'Hello there',
        'mailto:someone@example.com',
        'https://',
        'ht!tp://[bad',
      ]) {
        final code = ReadCode.read(text);
        expect(code.kind, CodeKind.text, reason: text);
        expect(code.link, isNull);
      }
    });

    test('knows a Wi-Fi network, with its password or without', () {
      final home = ReadCode.read(r'WIFI:S:Home\;Net;T:WPA;P:pa\:ss\\word;;');
      expect(home.kind, CodeKind.wifi);
      expect(home.network, 'Home;Net');
      expect(home.password, r'pa:ss\word');

      final cafe = ReadCode.read('wifi:T:nopass;S:Cafe;;');
      expect(cafe.kind, CodeKind.wifi);
      expect(cafe.password, isEmpty);
    });

    test('takes a Wi-Fi code that names no network as words', () {
      expect(ReadCode.read('WIFI:T:WPA;P:secret;;').kind, CodeKind.text);
      expect(ReadCode.read(r'WIFI:nonsense\').kind, CodeKind.text);
    });

    test('compares by what it says', () {
      expect(ReadCode.read('abc'), ReadCode.read('abc'));
      expect(ReadCode.read('abc'), isNot(ReadCode.read('abd')));
    });
  });
}
