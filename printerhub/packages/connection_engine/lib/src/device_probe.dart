import 'package:connection_engine/src/device.dart';
import 'package:connection_engine/src/mapping.dart';
import 'package:printer_protocols/printer_protocols.dart';

enum ProbeFailureKind {
  /// What was typed is not an address.
  invalidAddress,

  /// Nothing answered there.
  unreachable,

  /// Something answered, but not a printer or scanner the app can talk to.
  notAPrinter,
}

/// A device could not be found, or is not one the app can use.
class ProbeFailure implements Exception {
  const new(this.kind, this.address);

  final ProbeFailureKind kind;
  final String address;

  @override
  String toString() => 'ProbeFailure(${kind.name}: $address)';
}

/// The attributes that change while a printer runs. Asking for these alone
/// keeps a status check small.
const List<String> _statusAttributes = [
  'printer-state',
  'printer-state-reasons',
  'printer-is-accepting-jobs',
  'queued-job-count',
  'marker-names',
  'marker-types',
  'marker-colors',
  'marker-levels',
];

/// Asks a device on the network what it is and what it can do.
class DeviceProbe {
  new({required this._http});

  final PrinterHttp _http;

  /// Finds the device at [address] and describes it.
  ///
  /// [address] may be an IP address or a host name, with or without a port,
  /// or a full `ipp://`, `ipps://`, `http://`, or `https://` address.
  ///
  /// Throws [ProbeFailure] when it cannot.
  Future<DeviceDescription> probe(String address) async {
    final target = _parse(address);
    if (target == null) {
      throw ProbeFailure(ProbeFailureKind.invalidAddress, address);
    }
    return await _describe(target, address);
  }

  /// Describes a device that announced where it prints and scans, as one
  /// found by network discovery does. An address it did not announce is
  /// looked for in the usual places.
  Future<DeviceDescription> probeAnnounced({
    required String host,
    Uri? ipp,
    Uri? escl,
  }) {
    return _describe(_Target.announced(host, ipp: ipp, escl: escl), host);
  }

  Future<DeviceDescription> _describe(_Target target, String address) async {
    final attempt = _Attempt();
    // Printing and scanning are asked about at the same time: a device that
    // has one and not the other should not take twice as long.
    final (printing, scanning) = await (
      _findIpp(target, attempt),
      _findEscl(target, attempt),
    ).wait;
    if (printing == null && scanning == null) {
      throw ProbeFailure(
        attempt.somethingAnswered
            ? ProbeFailureKind.notAPrinter
            : ProbeFailureKind.unreachable,
        address,
      );
    }

    final printer = printing?.$2;
    final scanner = scanning?.$2;
    final named = splitMakeAndModel(
      printer?.makeAndModel ?? scanner?.makeAndModel,
    );
    final deviceId = printer?.deviceId;

    return DeviceDescription(
      host: target.host,
      connections: [?printing?.$1, ?scanning?.$1],
      name: printer?.name,
      manufacturer:
          deviceIdField(deviceId, const ['MFG', 'MANUFACTURER']) ??
          named.manufacturer,
      model: deviceIdField(deviceId, const ['MDL', 'MODEL']) ?? named.model,
      serialNumber:
          deviceIdField(deviceId, const ['SN', 'SERN', 'SERIALNUMBER']) ??
          scanner?.serialNumber,
      uuid: printer?.uuid ?? scanner?.uuid,
      print: printer == null ? null : printFeaturesFrom(printer),
      scan: scanner == null ? null : scanFeaturesFrom(scanner),
      status: deviceStatusFrom(printer, scanner: scanning?.$3),
    );
  }

  /// Reads what a known device is doing, through its saved [connections].
  ///
  /// Never throws: a device that does not answer is `unreachable`.
  Future<DeviceStatus> status(List<DeviceConnection> connections) async {
    IppPrinterAttributes? printer;
    EsclStatus? scanner;
    var reached = false;

    for (final connection in connections) {
      try {
        if (connection.type == 'escl') {
          scanner ??= await EsclClient(
            baseUri: connection.uri,
            http: _http,
          ).status();
        } else {
          printer ??= await IppClient(
            printerUri: connection.uri,
            http: _http,
          ).getPrinterAttributes(requested: _statusAttributes);
        }
        reached = true;
      } on PrinterUnreachable {
        continue;
      } on IppException {
        // It answered, to say it cannot serve right now.
        reached = true;
      } on IppNotAvailable {
        continue;
      } on EsclException {
        continue;
      }
    }

    if (printer == null && scanner == null) {
      return reached
          ? const DeviceStatus(state: 'offline', acceptingJobs: false)
          : DeviceStatus.unreachable;
    }
    return deviceStatusFrom(printer, scanner: scanner);
  }

  Future<(DeviceConnection, IppPrinterAttributes)?> _findIpp(
    _Target target,
    _Attempt attempt,
  ) async {
    for (final uri in target.ippCandidates) {
      try {
        final printer = await IppClient(
          printerUri: uri,
          http: _http,
        ).getPrinterAttributes();
        return (
          DeviceConnection(
            type: uri.scheme == 'ipps' ? 'ipps' : 'ipp',
            uri: uri,
          ),
          printer,
        );
      } on PrinterUnreachable {
        continue;
      } on IppNotAvailable {
        attempt.somethingAnswered = true;
      } on IppException {
        attempt.somethingAnswered = true;
      }
    }
    return null;
  }

  Future<(DeviceConnection, EsclCapabilities, EsclStatus?)?> _findEscl(
    _Target target,
    _Attempt attempt,
  ) async {
    for (final uri in target.esclCandidates) {
      final client = EsclClient(baseUri: uri, http: _http);
      try {
        final capabilities = await client.capabilities();
        EsclStatus? status;
        try {
          status = await client.status();
        } on Exception {
          // Capabilities are what matter here; status is a bonus.
        }
        return (DeviceConnection(type: 'escl', uri: uri), capabilities, status);
      } on PrinterUnreachable {
        continue;
      } on EsclException {
        attempt.somethingAnswered = true;
      }
    }
    return null;
  }

  static _Target? _parse(String address) {
    final text = address.trim();
    if (text.isEmpty || text.contains(' ')) return null;

    final Uri uri;
    try {
      uri = Uri.parse(text.contains('://') ? text : '//$text');
    } on FormatException {
      return null;
    }
    if (uri.host.isEmpty) return null;
    return _Target(uri);
  }
}

class _Attempt {
  bool somethingAnswered = false;
}

/// An address as typed, and the places worth trying for it.
class _Target {
  new(this._uri) : _ipp = null, _escl = null;

  new announced(String host, {this._ipp, this._escl}) : _uri = Uri(host: host);

  final Uri _uri;

  /// Where the device said it prints and scans, when it said.
  final Uri? _ipp;
  final Uri? _escl;

  String get host => _uri.host;
  bool get _hasPort => _uri.hasPort;
  bool get _secure => _uri.scheme == 'ipps' || _uri.scheme == 'https';

  Uri _build(String scheme, int port, String path) {
    return Uri(scheme: scheme, host: host, port: port, path: path);
  }

  List<Uri> get ippCandidates {
    if (_ipp != null) return [_ipp];
    final path = _uri.path.isEmpty || _uri.path == '/'
        ? '/ipp/print'
        : _uri.path;
    // A port was given: that is where to look, and nowhere else.
    if (_hasPort) {
      return [_build(_secure ? 'ipps' : 'ipp', _uri.port, path)];
    }
    return [
      if (!_secure) _build('ipp', 631, path),
      _build('ipps', 631, path),
      _build('ipps', 443, path),
    ];
  }

  List<Uri> get esclCandidates {
    if (_escl != null) return [_escl];
    if (_hasPort) {
      return [_build(_secure ? 'https' : 'http', _uri.port, '/eSCL')];
    }
    return [
      if (!_secure) _build('http', 80, '/eSCL'),
      _build('https', 443, '/eSCL'),
      if (!_secure) _build('http', 8080, '/eSCL'),
    ];
  }
}
