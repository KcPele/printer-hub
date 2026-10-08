import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:printer_discovery/printer_discovery.dart';
import 'package:printer_discovery/testing.dart';

void main() {
  group('textOfNdefRecord', () {
    test('reads a link, restoring its abbreviated start', () {
      expect(
        textOfNdefRecord(
          type: 'U',
          payload: [4, ...utf8.encode('printer.local')],
        ),
        'https://printer.local',
      );
      expect(
        textOfNdefRecord(
          type: 'U',
          payload: [0, ...utf8.encode('printerhub://pair?token=abc')],
        ),
        'printerhub://pair?token=abc',
      );
      expect(
        textOfNdefRecord(type: 'U', payload: [200, ...utf8.encode('x')]),
        'x',
      );
    });

    test('reads text, skipping its language', () {
      expect(
        textOfNdefRecord(
          type: 'T',
          payload: [2, ...utf8.encode('en'), ...utf8.encode('192.168.1.40')],
        ),
        '192.168.1.40',
      );
      expect(textOfNdefRecord(type: 'T', payload: [5, 1]), isNull);
    });

    test('reads the Wi-Fi network a printer hands over', () {
      List<int> field(int id, List<int> value) => [
        id >> 8,
        id & 0xFF,
        value.length >> 8,
        value.length & 0xFF,
        ...value,
      ];
      final credential = [
        ...field(0x1045, utf8.encode('DIRECT-AB;C7130')),
        ...field(0x1027, utf8.encode('secret123')),
      ];

      final text = textOfNdefRecord(
        type: 'application/vnd.wfa.wsc',
        payload: field(0x100E, credential),
      )!;

      expect(
        ScannedCode.parse(text),
        const WifiNetworkCode(ssid: 'DIRECT-AB;C7130', password: 'secret123'),
      );
      expect(
        ScannedCode.parse(
          textOfNdefRecord(
            type: 'application/vnd.wfa.wsc',
            payload: field(0x1045, utf8.encode('Open')),
          )!,
        ),
        const WifiNetworkCode(ssid: 'Open'),
      );
    });

    test('gives up on a Wi-Fi record that is cut short or has no name', () {
      expect(
        textOfNdefRecord(
          type: 'application/vnd.wfa.wsc',
          payload: [0x10, 0x45, 0, 9, 1],
        ),
        isNull,
      );
      expect(
        textOfNdefRecord(
          type: 'application/vnd.wfa.wsc',
          payload: [0x10, 0x27, 0, 1, 65],
        ),
        isNull,
      );
    });

    test('reads plain text and JSON by their MIME type', () {
      expect(
        textOfNdefRecord(type: 'text/plain', payload: utf8.encode('hello')),
        'hello',
      );
      expect(
        textOfNdefRecord(type: 'application/json', payload: utf8.encode('{}')),
        '{}',
      );
    });

    test('has nothing for an empty record or an unknown type', () {
      expect(textOfNdefRecord(type: 'U', payload: []), isNull);
      expect(textOfNdefRecord(type: 'image/png', payload: [1, 2]), isNull);
    });
  });

  group('Bluetooth sightings', () {
    const near = BluetoothSighting(id: '1', name: 'Xerox C7130', signal: -40);
    const room = BluetoothSighting(id: '2', name: 'HP LaserJet', signal: -70);
    const far = BluetoothSighting(id: '3', name: 'Canon', signal: -90);

    test('say how close the device is', () {
      expect(near.nearness, Nearness.besideYou);
      expect(room.nearness, Nearness.inTheRoom);
      expect(far.nearness, Nearness.furtherAway);
      // Built at run time, so equality is by value and not by identity.
      BluetoothSighting seen(int signal) =>
          BluetoothSighting(id: '1', name: 'Xerox C7130', signal: signal);
      expect(seen(-40), seen(-40));
      expect(seen(-40), isNot(seen(-41)));
    });

    test('are ordered nearest first, without the nameless ones', () {
      expect(
        orderSightings([
          far,
          const BluetoothSighting(id: '4', name: '  ', signal: -30),
          near,
          room,
        ]),
        [near, room, far],
      );
    });

    test('are matched to the network device with the most similar name', () {
      const xerox = NearbyDevice(
        name: 'Front desk',
        host: '10.0.0.5',
        model: 'Xerox VersaLink C7130',
      );
      const hp = NearbyDevice(name: 'HP LaserJet Pro M404', host: '10.0.0.6');

      expect(matchSighting(near, [hp, xerox]), xerox);
      expect(matchSighting(room, [xerox, hp]), hp);
      expect(matchSighting(far, [xerox, hp]), isNull);
      expect(matchSighting(near, const []), isNull);
    });
  });

  group('the stand-ins behave like the real finders', () {
    test('network discovery replays what is announced', () async {
      final network = FakeNetworkDiscovery();
      const device = NearbyDevice(name: 'A', host: 'h');
      final seen = <List<NearbyDevice>>[];
      final subscription = network.watch().listen(seen.add);
      await pumpEventQueue();
      expect(network.listeners, 1);

      network.announce([device]);
      await pumpEventQueue();
      await subscription.cancel();

      expect(seen, [
        <NearbyDevice>[],
        [device],
      ]);
      expect(network.listeners, 0);
    });

    test('the NFC reader reads what is tapped', () async {
      final nfc = FakeNfcReader();
      expect(await nfc.isAvailable, isTrue);

      final reading = nfc.read();
      nfc.tap('192.168.1.40');
      expect(await reading, '192.168.1.40');

      final failing = nfc.read();
      nfc.fail(StateError('tag lost'));
      await expectLater(failing, throwsStateError);

      await nfc.cancel();
      expect(nfc.cancelled, isTrue);
    });

    test('the Bluetooth scanner reports what is around', () async {
      final bluetooth = FakeBluetoothScanner();
      expect(await bluetooth.isAvailable, isTrue);
      final seen = <List<BluetoothSighting>>[];
      final subscription = bluetooth.scan().listen(seen.add);
      await pumpEventQueue();

      bluetooth.see(const [BluetoothSighting(id: '1', name: 'X', signal: -50)]);
      await pumpEventQueue();
      await subscription.cancel();

      expect(seen.last.single.name, 'X');
    });

    test('the Wi-Fi network answers with its gateway', () async {
      expect(
        await FakeWifiNetwork('192.168.223.1').gatewayAddress(),
        '192.168.223.1',
      );
      expect(await FakeWifiNetwork().gatewayAddress(), isNull);
    });
  });
}
