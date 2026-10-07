import 'package:connection_engine/connection_engine.dart';
import 'package:test/test.dart';

void main() {
  group('CertificateTrust', () {
    test('trusts a device the first time and remembers it', () {
      final remembered = <String, String>{};
      final trust = CertificateTrust(onTrusted: (d, f) => remembered[d] = f);

      expect(trust.check('printer.local', 631, 'aa'), isTrue);
      expect(trust.check('printer.local', 631, 'aa'), isTrue);

      expect(remembered, {'printer.local:631': 'aa'});
      expect(trust.changed, isEmpty);
    });

    test('refuses a device whose certificate changed', () {
      final trust = CertificateTrust(known: {'printer.local:631': 'aa'});

      expect(trust.check('printer.local', 631, 'bb'), isFalse);

      expect(trust.changed, {'printer.local:631'});
    });

    test('tells devices apart by port', () {
      final trust = CertificateTrust(known: {'printer.local:631': 'aa'});

      expect(trust.check('printer.local', 443, 'bb'), isTrue);
    });

    test('accepts a new certificate once the old one is forgotten', () {
      final trust = CertificateTrust(known: {'printer.local:631': 'aa'})
        ..check('printer.local', 631, 'bb')
        ..forget('printer.local', 631);

      expect(trust.changed, isEmpty);
      expect(trust.check('printer.local', 631, 'bb'), isTrue);
    });
  });
}
