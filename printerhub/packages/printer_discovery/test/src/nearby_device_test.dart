import 'package:flutter_test/flutter_test.dart';
import 'package:printer_discovery/printer_discovery.dart';

ServiceAnnouncement _service(
  String type, {
  String name = 'Xerox VersaLink C7130 (ab:cd)',
  int port = 631,
  List<String> addresses = const ['192.168.1.40'],
  String? hostname,
  Map<String, String> attributes = const {},
}) {
  return ServiceAnnouncement(
    name: name,
    type: type,
    port: port,
    addresses: addresses,
    hostname: hostname,
    attributes: attributes,
  );
}

void main() {
  group('deviceFromAnnouncement', () {
    test('reads a print service', () {
      final device = deviceFromAnnouncement(
        _service(
          '_ipp._tcp',
          attributes: {
            'ty': 'Xerox VersaLink C7130',
            'rp': 'ipp/print',
            'UUID': 'u-1',
          },
        ),
      )!;

      expect(device.name, 'Xerox VersaLink C7130 (ab:cd)');
      expect(device.host, '192.168.1.40');
      expect(device.model, 'Xerox VersaLink C7130');
      expect(device.uuid, 'u-1');
      expect(device.ipp, Uri.parse('ipp://192.168.1.40:631/ipp/print'));
      expect(device.prints, isTrue);
      expect(device.scans, isFalse);
      expect(device.key, 'u-1');
    });

    test('reads a secure print service at its own path', () {
      final device = deviceFromAnnouncement(
        _service('_ipps._tcp.', port: 443, attributes: {'rp': 'printers/main'}),
      )!;

      expect(device.ipp, Uri.parse('ipps://192.168.1.40:443/printers/main'));
    });

    test('reads a scan service, plain and secure', () {
      final plain = deviceFromAnnouncement(
        _service('_uscan._tcp', port: 80, attributes: {'rs': 'eSCL'}),
      )!;
      final secure = deviceFromAnnouncement(
        _service('_uscans._tcp', port: 443, attributes: {'rp': 'eSCL'}),
      )!;

      expect(plain.escl, Uri.parse('http://192.168.1.40:80/eSCL'));
      expect(plain.scans, isTrue);
      expect(plain.prints, isFalse);
      expect(secure.escl, Uri.parse('https://192.168.1.40:443/eSCL'));
      expect(plain.key, '192.168.1.40');
    });

    test('prefers an IPv4 address, then the local name', () {
      expect(
        deviceFromAnnouncement(
          _service('_ipp._tcp', addresses: ['fe80::1', '10.0.0.5']),
        )!.host,
        '10.0.0.5',
      );
      expect(
        deviceFromAnnouncement(
          _service('_ipp._tcp', addresses: [], hostname: 'printer.local'),
        )!.host,
        'printer.local',
      );
    });

    test('skips a service with no address, or of another kind', () {
      expect(
        deviceFromAnnouncement(_service('_ipp._tcp', addresses: [])),
        isNull,
      );
      expect(
        deviceFromAnnouncement(
          _service('_ipp._tcp', addresses: [], hostname: ''),
        ),
        isNull,
      );
      expect(deviceFromAnnouncement(_service('_airplay._tcp')), isNull);
    });

    test('ignores an empty attribute', () {
      final device = deviceFromAnnouncement(
        _service('_ipp._tcp', attributes: {'ty': '', 'TY': 'Canon'}),
      )!;

      expect(device.model, 'Canon');
    });
  });

  group('NearbyDevices', () {
    test('shows one device for a printer that prints and scans', () {
      final found = NearbyDevices();

      expect(
        found.found(_service('_ipp._tcp', attributes: {'ty': 'C7130'})),
        isTrue,
      );
      expect(found.found(_service('_ipps._tcp', port: 443)), isTrue);
      expect(found.found(_service('_uscan._tcp', port: 80)), isTrue);

      final device = found.devices.single;
      expect(device.ipp, Uri.parse('ipp://192.168.1.40:631/ipp/print'));
      expect(device.escl, Uri.parse('http://192.168.1.40:80/eSCL'));
      expect(device.model, 'C7130');
    });

    test('keeps different devices apart, in name order', () {
      final found = NearbyDevices()
        ..found(_service('_ipp._tcp', name: 'Zebra', addresses: ['10.0.0.9']))
        ..found(
          _service('_ipp._tcp', name: 'brother', addresses: ['10.0.0.8']),
        );

      expect(found.devices.map((d) => d.name), ['brother', 'Zebra']);
    });

    test('says whether anything changed', () {
      final found = NearbyDevices();

      expect(found.found(_service('_ipp._tcp')), isTrue);
      expect(found.found(_service('_ipp._tcp')), isFalse);
      expect(found.found(_service('_http._tcp')), isFalse);
      expect(found.found(_service('_ipp._tcp', port: 632)), isTrue);
    });

    test('forgets a service that went away', () {
      final found = NearbyDevices()
        ..found(_service('_ipp._tcp'))
        ..found(_service('_uscan._tcp', port: 80));

      expect(
        found.lost('Xerox VersaLink C7130 (ab:cd)', '_uscan._tcp'),
        isTrue,
      );
      expect(
        found.lost('Xerox VersaLink C7130 (ab:cd)', '_uscan._tcp'),
        isFalse,
      );
      expect(found.devices.single.scans, isFalse);

      found.lost('Xerox VersaLink C7130 (ab:cd)', '_ipp._tcp');
      expect(found.devices, isEmpty);
    });
  });

  test('NearbyDevice compares by what it holds', () {
    const a = NearbyDevice(name: 'A', host: 'h');

    expect(a, const NearbyDevice(name: 'A', host: 'h'));
    expect(a, isNot(const NearbyDevice(name: 'A', host: 'other')));
    expect(
      a.merge(const NearbyDevice(name: 'B', host: 'x', model: 'M')).model,
      'M',
    );
  });
}
