// Talks to the phone's Bluetooth radio through a plugin, so it cannot run
// in a unit test. What it feeds, orderSightings and matchSighting, is
// tested in full.
// coverage:ignore-file

import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:printer_discovery/src/finders.dart';

/// Scans for Bluetooth Low Energy devices with the phone's own radio.
class PluginBluetoothScanner implements BluetoothScanner {
  const new();

  @override
  Future<bool> get isAvailable async {
    try {
      if (!await FlutterBluePlus.isSupported) return false;
      // The state is unknown until the phone has said what it is: asking
      // for it at once, as the app starts, made a phone with Bluetooth on
      // look as though it had none. Wait for the first real answer.
      final state = await FlutterBluePlus.adapterState
          .firstWhere(
            (state) =>
                state != BluetoothAdapterState.unknown &&
                state != BluetoothAdapterState.turningOn,
          )
          .timeout(const Duration(seconds: 3));
      return state == BluetoothAdapterState.on;
    } on Object {
      return false;
    }
  }

  @override
  Stream<List<BluetoothSighting>> scan() {
    StreamSubscription<List<ScanResult>>? results;
    late final StreamController<List<BluetoothSighting>> controller;

    Future<void> start() async {
      controller.add(const []);
      results = FlutterBluePlus.scanResults.listen((found) {
        if (controller.isClosed) return;
        controller.add(
          orderSightings([
            for (final result in found)
              BluetoothSighting(
                id: result.device.remoteId.str,
                name: result.device.advName.isNotEmpty
                    ? result.device.advName
                    : result.device.platformName,
                signal: result.rssi,
              ),
          ]),
        );
      });
      try {
        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 20));
      } on Object catch (error) {
        if (!controller.isClosed) controller.addError(error);
      }
    }

    Future<void> stop() async {
      await results?.cancel();
      try {
        await FlutterBluePlus.stopScan();
      } on Object {
        // The scan had already ended.
      }
    }

    controller = StreamController<List<BluetoothSighting>>(
      onListen: start,
      onCancel: stop,
    );
    return controller.stream;
  }
}
