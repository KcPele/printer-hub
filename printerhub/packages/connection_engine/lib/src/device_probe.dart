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

  /// The printer wants a user name and password before it says anything.
  needsPassword,

  /// The printer did not accept the user name and password it was given.
  wrongPassword,
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
  ///
  /// [credentials] are for a printer that asks who is printing. Without
  /// them such a printer fails as [ProbeFailureKind.needsPassword].
  Future<DeviceDescription> probe(
    String address, {
    PrinterCredentials? credentials,
  }) async {
    final target = _parse(address);
    if (target == null) {
      throw ProbeFailure(ProbeFailureKind.invalidAddress, address);
    }
    return await _describe(target, address, credentials);
  }

  /// Describes a device that announced where it prints and scans, as one
  /// found by network discovery does. An address it did not announce is
  /// looked for in the usual places.
  Future<DeviceDescription> probeAnnounced({
    required String host,
    Uri? ipp,
    Uri? escl,
    PrinterCredentials? credentials,
  }) {
    return _describe(
      _Target.announced(host, ipp: ipp, escl: escl),
      host,
      credentials,
    );
  }

  Future<DeviceDescription> _describe(
    _Target target,
    String address,
    PrinterCredentials? credentials,
  ) async {
    final attempt = _Attempt();
    // Printing and scanning are asked about at the same time: a device that
    // has one and not the other should not take twice as long.
    final (printing, scanning) = await (
      _findIpp(target, attempt, credentials),
      _findEscl(target, attempt),
    ).wait;
    // A printer that would not say what it is without a password is not
    // added as a scanner alone: the person is asked for the password.
    if (printing == null && attempt.passwordRefused) {
      throw ProbeFailure(ProbeFailureKind.wrongPassword, address);
    }
    if (printing == null && attempt.passwordAsked) {
      throw ProbeFailure(ProbeFailureKind.needsPassword, address);
    }
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
  Future<DeviceStatus> status(
    List<DeviceConnection> connections, {
    PrinterCredentials? credentials,
  }) async {
    return (await check(connections, credentials: credentials)).status;
  }

  /// Tries every one of a known device's [connections] and says how each
  /// did, along with what the device is doing.
  ///
  /// They are tried at the same time, so one that has gone quiet does not
  /// hold up the others. Never throws.
  Future<({DeviceStatus status, List<ConnectionCheck> checks})> check(
    List<DeviceConnection> connections, {
    PrinterCredentials? credentials,
  }) async {
    final results = await Future.wait([
      for (final connection in connections) _try(connection, credentials),
    ]);
    final checks = [for (final result in results) result.check];
    // The first connection of each kind that answered speaks for the device.
    final printer = results.map((r) => r.printer).nonNulls.firstOrNull;
    final scanner = results.map((r) => r.scanner).nonNulls.firstOrNull;

    final DeviceStatus status;
    if (printer != null || scanner != null) {
      status = deviceStatusFrom(printer, scanner: scanner);
    } else if (checks.any((check) => check.health == 'degraded')) {
      // It spoke the protocol, to say it cannot serve right now.
      status = const DeviceStatus(state: 'offline', acceptingJobs: false);
    } else {
      status = DeviceStatus.unreachable;
    }
    return (status: status, checks: checks);
  }

  Future<_Tried> _try(
    DeviceConnection connection,
    PrinterCredentials? credentials,
  ) async {
    final clock = Stopwatch()..start();
    ConnectionCheck failed(String health, Object error) => ConnectionCheck(
      connection: connection,
      health: health,
      error: '$error',
    );

    try {
      if (connection.type == 'escl') {
        final scanner = await EsclClient(
          baseUri: connection.uri,
          http: _http,
        ).status();
        return _Tried(
          ConnectionCheck.connected(connection, clock.elapsed),
          scanner: scanner,
        );
      }
      final printer = await IppClient(
        printerUri: connection.uri,
        http: _http,
        credentials: credentials,
      ).getPrinterAttributes(requested: _statusAttributes);
      return _Tried(
        ConnectionCheck.connected(connection, clock.elapsed),
        printer: printer,
      );
    } on PrinterUnreachable catch (error) {
      return _Tried(failed('unavailable', error.cause));
    } on IppException catch (error) {
      // It answered, to say it cannot serve right now.
      return _Tried(failed('degraded', error));
    } on IppNotAvailable catch (error) {
      return _Tried(
        failed(
          error.needsAuthentication ? 'auth_required' : 'config_required',
          error,
        ),
      );
    } on EsclException catch (error) {
      return _Tried(
        failed(
          error.notSupported
              ? 'config_required'
              : error.busy
              ? 'degraded'
              : 'unavailable',
          error,
        ),
      );
    }
  }

  Future<(DeviceConnection, IppPrinterAttributes)?> _findIpp(
    _Target target,
    _Attempt attempt,
    PrinterCredentials? credentials,
  ) async {
    for (final endpoint in target.ippEndpoints) {
      paths:
      for (final path in target.ippPaths) {
        final uri = endpoint.replace(path: path);
        try {
          final printer = await IppClient(
            printerUri: uri,
            http: _http,
            credentials: credentials,
          ).getPrinterAttributes();
          return (
            DeviceConnection(
              type: uri.scheme == 'ipps' ? 'ipps' : 'ipp',
              uri: uri,
            ),
            printer,
          );
        } on PrinterUnreachable {
          // Nothing listens here, whatever the path.
          break paths;
        } on IppNotAvailable catch (error) {
          attempt.somethingAnswered = true;
          // Asked for here, whatever the path. That includes a password
          // this address is not safe to send to: the secure one is next.
          if (error.needsAuthentication) {
            attempt
              ..passwordAsked = true
              ..passwordRefused |= error.credentialsRefused;
            break paths;
          }
          if (error.needsTls) break paths;
          // Not at this path: older printers listen at another.
        } on IppException {
          attempt.somethingAnswered = true;
        }
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

/// What one connection gave when it was tried.
class _Tried {
  const new(this.check, {this.printer, this.scanner});

  final ConnectionCheck check;
  final IppPrinterAttributes? printer;
  final EsclStatus? scanner;
}

class _Attempt {
  bool somethingAnswered = false;
  bool passwordAsked = false;
  bool passwordRefused = false;
}

/// Where printers listen for IPP. The first is the standard; the rest are
/// where printers from before it, and print servers, put theirs.
const List<String> _ippPaths = ['/ipp/print', '/ipp/printer', '/ipp', '/'];

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

  /// The paths to try, in order. A path that was typed or announced is the
  /// only one.
  List<String> get ippPaths {
    if (_ipp != null) return [_ipp.path];
    return _uri.path.isEmpty || _uri.path == '/' ? _ippPaths : [_uri.path];
  }

  /// The ports to try, in order, without their paths.
  List<Uri> get ippEndpoints {
    if (_ipp != null) return [_ipp];
    // A port was given: that is where to look, and nowhere else.
    if (_hasPort) {
      return [_build(_secure ? 'ipps' : 'ipp', _uri.port, '')];
    }
    return [
      if (!_secure) _build('ipp', 631, ''),
      _build('ipps', 631, ''),
      _build('ipps', 443, ''),
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
