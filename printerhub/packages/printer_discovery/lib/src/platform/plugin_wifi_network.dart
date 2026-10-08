// Asks the operating system about the Wi-Fi connection through a plugin,
// so it cannot run in a unit test.
// coverage:ignore-file

import 'package:network_info_plus/network_info_plus.dart';
import 'package:printer_discovery/src/finders.dart';

class PluginWifiNetwork implements WifiNetwork {
  const new();

  @override
  Future<String?> gatewayAddress() async {
    try {
      final address = await NetworkInfo().getWifiGatewayIP();
      return address == null || address.isEmpty ? null : address;
    } on Object {
      return null;
    }
  }
}
