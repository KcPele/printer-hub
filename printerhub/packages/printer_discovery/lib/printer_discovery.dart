/// Finds printers near the phone: on the network, by QR code, NFC, and
/// Bluetooth.
library;

export 'src/finders.dart';
export 'src/ndef_text.dart';
export 'src/nearby_device.dart';
export 'src/platform/bonsoir_network_discovery.dart';
export 'src/platform/plugin_bluetooth_scanner.dart';
export 'src/platform/plugin_nfc_reader.dart';
export 'src/platform/plugin_wifi_network.dart';
export 'src/scanned_code.dart';
