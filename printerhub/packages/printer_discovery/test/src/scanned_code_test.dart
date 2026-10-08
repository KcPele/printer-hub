import 'package:flutter_test/flutter_test.dart';
import 'package:printer_discovery/printer_discovery.dart';

void main() {
  group('ScannedCode.parse', () {
    test('reads a pairing link', () {
      expect(
        ScannedCode.parse(' printerhub://pair?token=abc123 '),
        const PairingCode(token: 'abc123'),
      );
      expect(
        ScannedCode.parse(
          'printerhub://pair?token=abc&printer_id=p1&organization_id=o1',
        ),
        const PairingCode(token: 'abc', printerId: 'p1', organizationId: 'o1'),
      );
    });

    test('reads a pairing payload', () {
      expect(
        ScannedCode.parse(
          '{"v":1,"token":"abc","printer_id":"p1","organization_id":"o1"}',
        ),
        const PairingCode(token: 'abc', printerId: 'p1', organizationId: 'o1'),
      );
    });

    test('does not take other links or JSON for a pairing code', () {
      expect(ScannedCode.parse('printerhub://pair'), isA<UnrecognisedCode>());
      expect(
        ScannedCode.parse('printerhub://pair?token='),
        isA<UnrecognisedCode>(),
      );
      expect(ScannedCode.parse('{"model":"C7130"}'), isA<UnrecognisedCode>());
      expect(ScannedCode.parse('{not json'), isA<UnrecognisedCode>());
    });

    test('reads a printer address', () {
      for (final address in [
        'ipp://192.168.1.40:631/ipp/print',
        'ipps://printer.local/ipp/print',
        'http://192.168.1.40',
        'https://printer.example.com:8443/eSCL',
        '192.168.1.40',
        '192.168.1.40:631',
        'printer.local',
        'office-printer:8631',
      ]) {
        expect(ScannedCode.parse(address), PrinterAddressCode(address));
      }
    });

    test('reads the network a printer makes for itself', () {
      expect(
        ScannedCode.parse('WIFI:T:WPA;S:DIRECT-AB-C7130;P:secret123;;'),
        const WifiNetworkCode(ssid: 'DIRECT-AB-C7130', password: 'secret123'),
      );
      expect(
        ScannedCode.parse(r'wifi:S:Print\;Room\:2;T:WPA;P:a\\b;;'),
        const WifiNetworkCode(ssid: 'Print;Room:2', password: r'a\b'),
      );
      expect(
        ScannedCode.parse('WIFI:T:nopass;S:Open Printer;P:;;'),
        const WifiNetworkCode(ssid: 'Open Printer'),
      );
    });

    test('does not take a Wi-Fi code without a name for a network', () {
      expect(
        ScannedCode.parse('WIFI:T:WPA;P:secret;;'),
        isA<UnrecognisedCode>(),
      );
    });

    test('says so when the code is something else', () {
      for (final text in ['SN-0042-XYZ', 'hello', 'mailto:a@example.com', '']) {
        expect(ScannedCode.parse(text), UnrecognisedCode(text));
      }
    });

    test('codes compare by what they hold', () {
      expect(
        const PairingCode(token: 'a'),
        isNot(const PairingCode(token: 'b')),
      );
      expect(
        const WifiNetworkCode(ssid: 'a'),
        isNot(const WifiNetworkCode(ssid: 'a', password: 'p')),
      );
      expect(const UnrecognisedCode('x'), const UnrecognisedCode('x'));
      expect(const UnrecognisedCode('x'), isNot(const PrinterAddressCode('x')));
    });
  });
}
