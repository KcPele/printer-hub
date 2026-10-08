# printer_discovery

How the phone finds a printer without being told its address.

| Way | What it gives | Part |
|---|---|---|
| Wi-Fi (Bonjour, also called mDNS) | Printers on the same network, with where they print and scan | `NetworkDiscovery`, `NearbyDevices` |
| QR code | A pairing code, a printer address, or the printer's own Wi-Fi network | `ScannedCode.parse` |
| NFC tap | The same three things, read from the tag on the printer | `NfcReader`, `textOfNdefRecord` |
| Bluetooth | Which printer the phone is next to | `BluetoothScanner`, `matchSighting` |
| Wi-Fi Direct | The printer's address once the phone has joined its network | `WifiNetwork` |

**Bluetooth and NFC find a printer; they do not carry documents.** Office printers use Bluetooth to announce that they are there, and an NFC tag holds a few hundred bytes. The document always travels over the network.

## What is tested and what is not

Everything that decides something is pure Dart and tested: reading a code, decoding an NFC record, merging announcements into devices, ordering and matching Bluetooth sightings.

The four classes in `lib/src/platform/` hand those decisions their input from a phone's radios, through plugins. They cannot run in a unit test and are excluded from coverage. `testing.dart` has stand-ins for them.

Checked by hand: Bonjour discovery on the iOS simulator. Not yet checked on a real phone: NFC, Bluetooth, and the camera.

## What each platform needs

- **iOS:** the Bonjour service types and the usage texts are in `ios/Runner/Info.plist`. Reading NFC also needs the *Near Field Communication Tag Reading* capability on the app's identifier, which is set in the Apple Developer account.
- **Android:** the permissions are in `AndroidManifest.xml`. None of the radios is marked as required.
