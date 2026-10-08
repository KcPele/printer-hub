import 'package:equatable/equatable.dart';
import 'package:printer_discovery/src/nearby_device.dart';

/// Watches the local network for printers and scanners that announce
/// themselves (Bonjour, also called mDNS or DNS-SD).
abstract interface class NetworkDiscovery {
  /// The devices found so far, again each time the list changes. Looking
  /// starts when this is listened to and stops when the listener cancels.
  Stream<List<NearbyDevice>> watch();
}

/// Reads the tag on a printer when the phone is tapped against it.
abstract interface class NfcReader {
  /// False on a phone without NFC, or with it switched off.
  Future<bool> get isAvailable;

  /// Waits for a tag and returns the text of its first readable record, or
  /// null when the tag holds nothing readable. Throws when reading fails.
  Future<String?> read();

  /// Stops waiting for a tag.
  Future<void> cancel();
}

/// How close a Bluetooth signal says a device is.
enum Nearness { besideYou, inTheRoom, furtherAway }

/// A device seen over Bluetooth.
///
/// Office printers use Bluetooth to say "I am here", not to carry
/// documents, so this tells which printer you are standing next to. The
/// document still travels over Wi-Fi.
class BluetoothSighting extends Equatable {
  const new({required this.id, required this.name, required this.signal});

  final String id;
  final String name;

  /// Signal strength in dBm: closer to zero is stronger.
  final int signal;

  Nearness get nearness => switch (signal) {
    >= -55 => Nearness.besideYou,
    >= -75 => Nearness.inTheRoom,
    _ => Nearness.furtherAway,
  };

  @override
  List<Object> get props => [id, name, signal];
}

/// Looks for devices announcing themselves over Bluetooth.
abstract interface class BluetoothScanner {
  /// False on a phone without Bluetooth, or with it switched off.
  Future<bool> get isAvailable;

  /// The named devices seen so far, nearest first, again each time the list
  /// changes. Scanning starts on listen and stops on cancel.
  Stream<List<BluetoothSighting>> scan();
}

/// What the phone knows about the Wi-Fi network it is on.
abstract interface class WifiNetwork {
  /// The address of the device that runs the network. On a printer's own
  /// Wi-Fi (Wi-Fi Direct) that device is the printer.
  Future<String?> gatewayAddress();
}

/// Orders sightings nearest first and drops devices that have no name,
/// which nobody could pick out of a list.
List<BluetoothSighting> orderSightings(Iterable<BluetoothSighting> sightings) {
  return [
    for (final sighting in sightings)
      if (sighting.name.trim().isNotEmpty) sighting,
  ]..sort((a, b) => b.signal.compareTo(a.signal));
}

/// The discovered device a Bluetooth sighting most likely is, or null.
///
/// A printer announces a similar name over Bluetooth and over the network,
/// so the two are matched by the words their names share.
NearbyDevice? matchSighting(
  BluetoothSighting sighting,
  Iterable<NearbyDevice> devices,
) {
  Set<String> words(String text) => {
    for (final word in text.toLowerCase().split(RegExp('[^a-z0-9]+')))
      if (word.length > 2) word,
  };

  final wanted = words(sighting.name);
  NearbyDevice? best;
  var bestScore = 0;
  for (final device in devices) {
    final score = wanted
        .intersection(words('${device.name} ${device.model ?? ''}'))
        .length;
    if (score > bestScore) {
      best = device;
      bestScore = score;
    }
  }
  return best;
}
