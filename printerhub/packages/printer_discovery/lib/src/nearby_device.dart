import 'package:equatable/equatable.dart';

/// A printer or scanner that announced itself on the network.
class NearbyDevice extends Equatable {
  const new({
    required this.name,
    required this.host,
    this.model,
    this.uuid,
    this.ipp,
    this.escl,
  });

  /// The name the device announces, such as "Xerox VersaLink C7130 (ab:cd)".
  final String name;

  /// An IP address when one is known, else the device's `.local` name.
  final String host;

  /// The maker and model, when the device says.
  final String? model;
  final String? uuid;

  /// Where it prints, when it announced a print service.
  final Uri? ipp;

  /// Where it scans, when it announced a scan service.
  final Uri? escl;

  bool get prints => ipp != null;
  bool get scans => escl != null;

  /// What tells one physical device from another: its UUID when it gives
  /// one, else where it is.
  String get key => uuid ?? host;

  /// The same device with whatever [other] knows that this does not.
  NearbyDevice merge(NearbyDevice other) {
    return NearbyDevice(
      name: name,
      host: host,
      model: model ?? other.model,
      uuid: uuid ?? other.uuid,
      ipp: ipp ?? other.ipp,
      escl: escl ?? other.escl,
    );
  }

  @override
  List<Object?> get props => [name, host, model, uuid, ipp, escl];
}

/// One service announcement, as a discovery plugin reports it.
class ServiceAnnouncement {
  const new({
    required this.name,
    required this.type,
    required this.port,
    this.addresses = const [],
    this.hostname,
    this.attributes = const {},
  });

  final String name;

  /// Such as `_ipp._tcp`.
  final String type;
  final int port;
  final List<String> addresses;
  final String? hostname;

  /// The TXT record: `ty` (model), `rp` (path), `UUID`, and more.
  final Map<String, String> attributes;
}

/// The service types the app looks for: printing, plain and secure, and
/// scanning, plain and secure.
const List<String> printerServiceTypes = [
  '_ipp._tcp',
  '_ipps._tcp',
  '_uscan._tcp',
  '_uscans._tcp',
];

/// Turns one announcement into a device, or null when it cannot be reached
/// (no address) or is not a kind the app looks for.
NearbyDevice? deviceFromAnnouncement(ServiceAnnouncement service) {
  final type = service.type.replaceFirst(RegExp(r'\.$'), '');
  if (!printerServiceTypes.contains(type)) return null;

  // IPv4 first: printers are reached far more reliably over it.
  final addresses = [...service.addresses]
    ..sort((a, b) => (a.contains(':') ? 1 : 0) - (b.contains(':') ? 1 : 0));
  final host = addresses.firstOrNull ?? service.hostname;
  if (host == null || host.isEmpty) return null;

  String? attribute(String name) {
    for (final entry in service.attributes.entries) {
      if (entry.key.toLowerCase() == name && entry.value.isNotEmpty) {
        return entry.value;
      }
    }
    return null;
  }

  final secure = type == '_ipps._tcp' || type == '_uscans._tcp';
  final path = attribute('rp');
  final isScan = type.startsWith('_uscan');
  final uri = Uri(
    scheme: isScan ? (secure ? 'https' : 'http') : (secure ? 'ipps' : 'ipp'),
    host: host,
    port: service.port,
    path: '/${path ?? (isScan ? 'eSCL' : 'ipp/print')}',
  );

  return NearbyDevice(
    name: service.name,
    host: host,
    model: attribute('ty'),
    uuid: attribute('uuid'),
    ipp: isScan ? null : uri,
    escl: isScan ? uri : null,
  );
}

/// Collects announcements into devices: one physical printer appears once,
/// even when it announces printing and scanning separately.
class NearbyDevices {
  final Map<String, NearbyDevice> _byName = {};

  /// Adds or updates what [service] announces. Returns true when the list
  /// changed.
  bool found(ServiceAnnouncement service) {
    final device = deviceFromAnnouncement(service);
    if (device == null) return false;
    final key = '${service.name}|${service.type}';
    if (_byName[key] == device) return false;
    _byName[key] = device;
    return true;
  }

  /// Removes what [name] announced under [type]. Returns true when the list
  /// changed.
  bool lost(String name, String type) {
    return _byName.remove('$name|$type') != null;
  }

  /// The devices found so far, by name.
  List<NearbyDevice> get devices {
    final merged = <String, NearbyDevice>{};
    for (final device in _byName.values) {
      final existing = merged[device.key];
      // A plain service is preferred over its secure twin for the address
      // shown, but nothing either one knows is lost.
      merged[device.key] = existing == null ? device : existing.merge(device);
    }
    return merged.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
}
