import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:printer_discovery/printer_discovery.dart';

/// The printers announcing themselves on the Wi-Fi network, for as long as
/// something is watching.
class NearbyPrintersCubit extends Cubit<List<NearbyDevice>> {
  new({required NetworkDiscovery discovery}) : super(const []) {
    _subscription = discovery.watch().listen(
      emit,
      // Discovery failing is the same, to the user, as finding nothing.
      onError: (Object _) {},
    );
  }

  late final StreamSubscription<List<NearbyDevice>> _subscription;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}

/// The devices seen over Bluetooth, nearest first, for as long as something
/// is watching.
class BluetoothSightingsCubit extends Cubit<List<BluetoothSighting>> {
  new({required BluetoothScanner scanner}) : super(const []) {
    _subscription = scanner.scan().listen(emit, onError: (Object _) {});
  }

  late final StreamSubscription<List<BluetoothSighting>> _subscription;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
