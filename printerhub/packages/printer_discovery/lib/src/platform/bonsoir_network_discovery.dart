// Talks to the platform's Bonjour service through a plugin, so it cannot
// run in a unit test. What it feeds, NearbyDevices, is tested in full.
// coverage:ignore-file

import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:printer_discovery/src/finders.dart';
import 'package:printer_discovery/src/nearby_device.dart';

/// Finds printers with the operating system's own Bonjour browser.
class BonsoirNetworkDiscovery implements NetworkDiscovery {
  const new();

  @override
  Stream<List<NearbyDevice>> watch() {
    final found = NearbyDevices();
    final discoveries = <BonsoirDiscovery>[];
    final subscriptions = <StreamSubscription<BonsoirDiscoveryEvent>>[];
    late final StreamController<List<NearbyDevice>> controller;

    ServiceAnnouncement announcement(BonsoirService service) {
      return ServiceAnnouncement(
        name: service.name,
        type: service.type,
        port: service.port,
        addresses: service.hostAddresses,
        hostname: service.hostname,
        attributes: service.attributes,
      );
    }

    Future<void> start() async {
      controller.add(const []);
      for (final type in printerServiceTypes) {
        try {
          final discovery = BonsoirDiscovery(type: type);
          await discovery.initialize();
          discoveries.add(discovery);
          subscriptions.add(
            discovery.eventStream!.listen((event) {
              var changed = false;
              switch (event) {
                case BonsoirDiscoveryServiceFoundEvent():
                  // Found is only a name. Resolving asks for the address.
                  unawaited(event.service.resolve(discovery.serviceResolver));
                case BonsoirDiscoveryServiceResolvedEvent():
                  changed = found.found(announcement(event.service));
                case BonsoirDiscoveryServiceUpdatedEvent():
                  changed = found.found(announcement(event.service));
                case BonsoirDiscoveryServiceLostEvent():
                  changed = found.lost(event.service.name, event.service.type);
                default:
                  break;
              }
              if (changed && !controller.isClosed) {
                controller.add(found.devices);
              }
            }),
          );
          await discovery.start();
        } on Object {
          // One service type failing to start must not stop the others.
          continue;
        }
      }
    }

    Future<void> stop() async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      for (final discovery in discoveries) {
        try {
          await discovery.stop();
        } on Object {
          continue;
        }
      }
    }

    controller = StreamController<List<NearbyDevice>>(
      onListen: start,
      onCancel: stop,
    );
    return controller.stream;
  }
}
