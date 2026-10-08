// Test support is not part of what the package ships to users.
// coverage:ignore-file

/// Stand-ins for the phone's radios, for tests of the screens built on them.
library;

import 'dart:async';

import 'package:printer_discovery/printer_discovery.dart';

/// A network on which tests decide what is announced.
class FakeNetworkDiscovery implements NetworkDiscovery {
  final _controller = StreamController<List<NearbyDevice>>.broadcast();
  List<NearbyDevice> _devices = const [];
  int listeners = 0;

  /// Announces [devices], replacing what was announced before.
  void announce(List<NearbyDevice> devices) {
    _devices = devices;
    _controller.add(devices);
  }

  @override
  Stream<List<NearbyDevice>> watch() async* {
    listeners++;
    try {
      yield _devices;
      yield* _controller.stream;
    } finally {
      listeners--;
    }
  }
}

/// An NFC reader that reads what the test puts on it.
class FakeNfcReader implements NfcReader {
  new({this.available = true});

  bool available;
  Completer<String?>? _waiting;
  bool cancelled = false;

  @override
  Future<bool> get isAvailable async => available;

  @override
  Future<String?> read() {
    cancelled = false;
    return (_waiting = Completer<String?>()).future;
  }

  /// Taps a tag holding [text] against the phone.
  void tap(String? text) => _waiting?.complete(text);

  /// Makes the read fail, as when the tag is pulled away too early.
  void fail(Object error) => _waiting?.completeError(error);

  @override
  Future<void> cancel() async => cancelled = true;
}

/// A Bluetooth radio that sees what the test says is around.
class FakeBluetoothScanner implements BluetoothScanner {
  new({this.available = true});

  bool available;
  final _controller = StreamController<List<BluetoothSighting>>.broadcast();

  void see(List<BluetoothSighting> sightings) {
    _controller.add(orderSightings(sightings));
  }

  @override
  Future<bool> get isAvailable async => available;

  @override
  Stream<List<BluetoothSighting>> scan() async* {
    yield const [];
    yield* _controller.stream;
  }
}

/// A Wi-Fi connection whose gateway the test chooses.
class FakeWifiNetwork implements WifiNetwork {
  new([this.gateway]);

  String? gateway;

  @override
  Future<String?> gatewayAddress() async => gateway;
}
