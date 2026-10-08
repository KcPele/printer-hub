import 'package:flutter/widgets.dart';
import 'package:printer_discovery/printer_discovery.dart';

/// Builds the camera view that reads QR codes, calling [onCode] with the
/// text of each code it sees.
typedef QrScannerBuilder = Widget Function(ValueChanged<String> onCode);

/// The ways the phone can find a printer, gathered so the app can be given
/// them in one piece: the real ones on a phone, stand-ins in a test.
class PrinterFinders {
  const new({
    required this.network,
    required this.nfc,
    required this.bluetooth,
    required this.wifi,
    required this.qrScanner,
  });

  /// Printers that announce themselves on the Wi-Fi network.
  final NetworkDiscovery network;

  /// The tag on a printer, read by tapping the phone against it.
  final NfcReader nfc;

  /// Printers that say "I am here" over Bluetooth.
  final BluetoothScanner bluetooth;

  /// The Wi-Fi network the phone is on.
  final WifiNetwork wifi;
  final QrScannerBuilder qrScanner;
}
