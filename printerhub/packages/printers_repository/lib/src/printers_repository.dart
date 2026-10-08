import 'dart:convert';

import 'package:api_client/api_client.dart';
import 'package:connection_engine/connection_engine.dart';
import 'package:local_store/local_store.dart';
import 'package:printer_protocols/printer_protocols.dart'
    show PrinterCredentials;
import 'package:printers_repository/src/api_mapping.dart';
import 'package:printers_repository/src/printer_family.dart';

/// The printers of a workspace.
///
/// The list lives on the backend, so everyone in the workspace sees the same
/// printers. What a printer is doing comes from the device itself, over the
/// local network, and is reported back for the others to see.
class PrintersRepository {
  new({
    required this._client,
    required this._probe,
    required this._runner,
    required this._scanner,
    required this._store,
  });

  static const int _pageSize = 100;

  final PrinterHubClient _client;
  final DeviceProbe _probe;
  final PrintRunner _runner;
  final ScanRunner _scanner;
  final SecureStore _store;

  static String _cacheKey(String organizationId) => 'printers.$organizationId';

  /// The catalogue is the same for everyone, so it is kept once.
  static const String _catalogueKey = 'catalogue';

  /// Where the passwords of a workspace's printers are kept on this phone,
  /// so a printer can still be used when the API cannot be reached.
  static String _credentialsKey(String organizationId) =>
      'printer-credentials.$organizationId';

  /// The workspace's printers.
  ///
  /// When the API cannot be reached, answers with the list from the last
  /// time it could, so a known printer can still be used. Throws an
  /// [ApiException] when there is no such list, or when the API refuses.
  Future<List<PrinterRead>> list(String organizationId) async {
    try {
      final printers = <PrinterRead>[];
      String? cursor;
      do {
        final page = await apiCall(
          () => _client.api.printers.listPrinters(
            orgId: organizationId,
            limit: _pageSize,
            cursor: cursor,
          ),
        );
        printers.addAll(page.items);
        cursor = page.nextCursor;
      } while (cursor != null);

      await _keep(organizationId, printers);
      return printers;
    } on ApiUnreachable {
      final kept = await _kept(organizationId);
      if (kept == null) rethrow;
      return kept;
    }
  }

  /// The catalogue of printer families, the ones most people have first.
  ///
  /// Answers from the last time it was read when the API cannot be
  /// reached. Throws an [ApiException] when there is nothing kept.
  Future<List<PrinterFamily>> families() async {
    try {
      final profiles = await apiCall(
        () => _client.api.capabilities.listProfiles(),
      );
      await _store.write(
        _catalogueKey,
        jsonEncode([for (final profile in profiles) profile.toJson()]),
      );
      return profiles.map(PrinterFamily.fromApi).toList();
    } on ApiUnreachable {
      final kept = await _keptFamilies();
      if (kept == null) rethrow;
      return kept;
    }
  }

  /// The family a printer belongs to, from the names it gives itself. Null
  /// when the catalogue has no such family, or cannot be asked.
  Future<PrinterFamily?> familyOf({
    required String? manufacturer,
    required String? model,
  }) async {
    if (manufacturer == null || model == null) return null;
    try {
      final profile = await apiCall(
        () => _client.api.capabilities.matchProfile(
          manufacturer: _makers[manufacturer.toLowerCase()] ?? manufacturer,
          model: model,
        ),
      );
      return PrinterFamily.fromApi(profile);
    } on ApiException {
      return null;
    }
  }

  /// Names a maker goes by other than the one the catalogue uses.
  static const Map<String, String> _makers = {
    'hewlett-packard': 'HP',
    'hewlett packard': 'HP',
    'fuji xerox': 'Xerox',
    'fujifilm business innovation': 'Xerox',
    'seiko epson': 'Epson',
    'kyocera document solutions': 'Kyocera',
  };

  Future<List<PrinterFamily>?> _keptFamilies() async {
    final json = await _store.read(_catalogueKey);
    if (json == null) return null;
    try {
      return [
        for (final item in jsonDecode(json) as List<dynamic>)
          PrinterFamily.fromApi(
            CapabilityProfileRead.fromJson(item as Map<String, dynamic>),
          ),
      ];
    } on Object {
      // Written by an older version of the app.
      return null;
    }
  }

  /// Asks the device at [address] what it is. Throws [ProbeFailure].
  ///
  /// A printer that asks who is printing fails as
  /// [ProbeFailureKind.needsPassword] until it is given [credentials].
  Future<DeviceDescription> probe(
    String address, {
    PrinterCredentials? credentials,
  }) {
    return _probe.probe(address, credentials: credentials);
  }

  /// Asks a device that announced itself on the network what it is.
  /// Throws [ProbeFailure].
  Future<DeviceDescription> probeAnnounced({
    required String host,
    Uri? ipp,
    Uri? escl,
    PrinterCredentials? credentials,
  }) {
    return _probe.probeAnnounced(
      host: host,
      ipp: ipp,
      escl: escl,
      credentials: credentials,
    );
  }

  /// The user name and password [printer] asks for, or null when it asks
  /// for none, or when this member may not use them.
  ///
  /// They are kept by the backend, encrypted, so every member's phone can
  /// print. Once read they stay in this phone's keystore: the backend
  /// records every read, and a printer must be usable when the API cannot
  /// be reached. Pass [fresh] to read them again, after the printer has
  /// refused the ones kept.
  Future<PrinterCredentials?> credentialsFor({
    required String organizationId,
    required PrinterRead printer,
    bool fresh = false,
  }) async {
    final connection = printer.connections
        .where((connection) => connection.hasCredentials)
        .firstOrNull;
    if (connection == null) return null;

    final kept = await _keptCredentials(organizationId);
    final entry = kept[connection.id];
    if (entry != null && !fresh) {
      return PrinterCredentials(userName: entry['u']!, password: entry['p']!);
    }
    try {
      final read = await apiCall(
        () => _client.api.connections.readConnectionCredentials(
          orgId: organizationId,
          printerId: printer.id,
          connectionId: connection.id,
        ),
      );
      final userName = read.username;
      final password = read.password;
      if (userName == null || password == null) return null;

      kept[connection.id] = {'u': userName, 'p': password};
      await _store.write(_credentialsKey(organizationId), jsonEncode(kept));
      return PrinterCredentials(userName: userName, password: password);
    } on ApiException {
      // Out of reach, or this member is not allowed the password. Without
      // it the printer will ask, and the app will say so.
      return null;
    }
  }

  Future<Map<String, Map<String, String>>> _keptCredentials(
    String organizationId,
  ) async {
    final json = await _store.read(_credentialsKey(organizationId));
    if (json == null) return {};
    try {
      return {
        for (final MapEntry(:key, :value)
            in (jsonDecode(json) as Map<String, dynamic>).entries)
          key: Map<String, String>.from(value as Map),
      };
    } on Object {
      // Written by an older version of the app.
      return {};
    }
  }

  /// Makes a short-lived code another member can scan to open [printerId]
  /// on their phone. The answer is the link to put in a QR code, and when
  /// it stops working.
  Future<({String link, DateTime expiresAt})> createPairingCode({
    required String organizationId,
    required String printerId,
  }) async {
    final created = await apiCall(
      () => _client.api.pairing.createPairingToken(
        orgId: organizationId,
        printerId: printerId,
      ),
    );
    return (link: created.deepLink, expiresAt: created.expiresAt);
  }

  /// Exchanges a scanned pairing code for the printer it names. The user
  /// must already belong to that printer's workspace.
  Future<PrinterRead> redeemPairingCode(String token) async {
    final result = await apiCall(
      () => _client.api.pairing.redeemPairingToken(
        body: PairingRedeem(token: token),
      ),
    );
    return result.printer;
  }

  /// Adds a device that was just probed to the workspace.
  Future<PrinterRead> add({
    required String organizationId,
    required DeviceDescription device,
    required String name,
    String? location,
    PrinterCredentials? credentials,
  }) async {
    final printer = await apiCall(
      () => _client.api.printers.addPrinter(
        orgId: organizationId,
        body: printerToApi(
          device,
          name: name,
          location: location,
          credentials: credentials,
        ),
      ),
    );
    // What the device said about itself while it was probed is worth
    // keeping; a failure to record it does not undo adding the printer.
    return await _report(organizationId, printer, device.status) ?? printer;
  }

  /// Asks the printer itself what it is doing, and tells the backend.
  ///
  /// Every saved connection is tried, and the backend is told of any whose
  /// health has changed, so the rest of the workspace knows which way in
  /// works. Never throws for a device that does not answer: that is a
  /// status too. The returned printer is the backend's when it could be
  /// told, and the given one otherwise.
  Future<({PrinterRead printer, DeviceStatus status})> refreshStatus({
    required String organizationId,
    required PrinterRead printer,
  }) async {
    final saved = [
      for (final connection in printer.connections)
        if (connectionFromApi(connection) case final reachable?)
          (record: connection, reachable: reachable),
    ];
    final result = await _probe.check(
      [for (final connection in saved) connection.reachable],
      credentials: await credentialsFor(
        organizationId: organizationId,
        printer: printer,
      ),
    );

    await Future.wait([
      for (final (index, check) in result.checks.indexed)
        if (saved[index].record.health.json != check.health)
          _reportHealth(organizationId, saved[index].record, check),
    ]);
    final reported = await _report(organizationId, printer, result.status);
    return (printer: reported ?? printer, status: result.status);
  }

  Future<void> _reportHealth(
    String organizationId,
    ConnectionRead connection,
    ConnectionCheck check,
  ) async {
    try {
      await apiCall(
        () => _client.api.connections.reportConnectionHealth(
          orgId: organizationId,
          printerId: connection.printerId,
          connectionId: connection.id,
          body: ConnectionHealthReport(
            health: ConnectionHealth.fromJson(check.health),
            latencyMs: check.latencyMs,
            error: check.error == null || check.error!.length <= 500
                ? check.error
                : check.error!.substring(0, 500),
          ),
        ),
      );
    } on ApiException {
      // It is reported again the next time the printer is checked.
    }
  }

  /// Prints [document] on [printer], over the local network.
  ///
  /// The printer's connections are tried in the order saved. [reference]
  /// is a short code unique to this print, by which the job is found on
  /// the printer again should the connection drop.
  Future<PrinterPrint> print({
    required String organizationId,
    required PrinterRead printer,
    required PrintDocument document,
    required PrintRequest request,
    required String reference,
  }) async {
    final saved = {
      for (final connection in printer.connections)
        ?connectionFromApi(connection): connection.id,
    };
    final run = _runner.start(
      connections: saved.keys.toList(),
      document: document,
      request: request,
      reference: reference,
      credentials: await credentialsFor(
        organizationId: organizationId,
        printer: printer,
      ),
    );
    return PrinterPrint._(run, saved);
  }

  /// Asks [printer] what became of a print this phone sent and stopped
  /// following, because the app was closed. Nothing is sent to print.
  ///
  /// [title] and [reference] are what the print was started with;
  /// [printerJobRef] is the printer's number for it, when that was learned.
  /// Null when the printer cannot be asked now.
  Future<PrintProgress?> fate({
    required String organizationId,
    required PrinterRead printer,
    required String title,
    required String reference,
    String? printerJobRef,
  }) async {
    return await _runner.fate(
      connections: [
        for (final connection in printer.connections)
          ?connectionFromApi(connection),
      ],
      jobName: PrintRunner.jobNameFor(title, reference),
      printerJobId: int.tryParse(printerJobRef ?? ''),
      credentials: await credentialsFor(
        organizationId: organizationId,
        printer: printer,
      ),
    );
  }

  /// Scans on [printer], over the local network. Each page is kept in a
  /// file as it arrives.
  PrinterScan scan({
    required PrinterRead printer,
    required ScanRequest request,
  }) {
    final saved = {
      for (final connection in printer.connections)
        ?connectionFromApi(connection): connection.id,
    };
    return PrinterScan._(
      _scanner.start(connections: saved.keys.toList(), request: request),
      saved,
    );
  }

  /// One printer, as the backend has it now.
  Future<PrinterRead> get({
    required String organizationId,
    required String printerId,
  }) {
    return apiCall(
      () => _client.api.printers.getPrinter(
        orgId: organizationId,
        printerId: printerId,
      ),
    );
  }

  /// Asks the printer again what it can do, and records the answer.
  ///
  /// For when something about the printer has changed: a finisher fitted,
  /// scanning switched on. Throws [ProbeFailure] when the printer does not
  /// answer, and leaves the record as it was.
  Future<PrinterRead> recheck({
    required String organizationId,
    required PrinterRead printer,
  }) async {
    final saved = [
      for (final connection in printer.connections)
        ?connectionFromApi(connection),
    ];
    final host = saved.firstOrNull?.uri.host ?? '';
    final device = await _probe.probeAnnounced(
      host: host,
      ipp: saved.where((c) => c.type != 'escl').firstOrNull?.uri,
      escl: saved.where((c) => c.type == 'escl').firstOrNull?.uri,
      credentials: await credentialsFor(
        organizationId: organizationId,
        printer: printer,
      ),
    );
    return await apiCall(
      () => _client.api.printers.reportCapabilities(
        orgId: organizationId,
        printerId: printer.id,
        body: capabilitiesToApi(device),
      ),
    );
  }

  /// A printer's connections, the one tried first at the top.
  Future<List<ConnectionRead>> connections({
    required String organizationId,
    required String printerId,
  }) {
    return apiCall(
      () => _client.api.connections.listConnections(
        orgId: organizationId,
        printerId: printerId,
      ),
    );
  }

  /// Sets the order connections are tried in. [connectionIds] names every
  /// connection of the printer once, the preferred one first.
  Future<List<ConnectionRead>> setConnectionOrder({
    required String organizationId,
    required String printerId,
    required List<String> connectionIds,
  }) {
    return apiCall(
      () => _client.api.connections.setConnectionPriority(
        orgId: organizationId,
        printerId: printerId,
        body: ConnectionPriorityUpdate(connectionIds: connectionIds),
      ),
    );
  }

  Future<void> removeConnection({
    required String organizationId,
    required String printerId,
    required String connectionId,
  }) {
    return apiCall(
      () => _client.api.connections.removeConnection(
        orgId: organizationId,
        printerId: printerId,
        connectionId: connectionId,
      ),
    );
  }

  /// Saves the ways [device] answered that [printer] does not have yet,
  /// after the ones it has. Returns how many were added.
  ///
  /// For a printer that has moved to another address, or gained one.
  Future<int> addConnections({
    required String organizationId,
    required PrinterRead printer,
    required DeviceDescription device,
    PrinterCredentials? credentials,
  }) async {
    final known = {
      for (final connection in printer.connections)
        ?connectionFromApi(connection),
    };
    var added = 0;
    for (final connection in device.connections) {
      if (known.contains(connection)) continue;
      await apiCall(
        () => _client.api.connections.addConnection(
          orgId: organizationId,
          printerId: printer.id,
          // Without a priority it goes last: what works now stays first.
          body: connectionToApi(connection, null, credentials: credentials),
        ),
      );
      added++;
    }
    return added;
  }

  /// Replaces the user name and password kept with a connection, for a
  /// printer whose password has been changed.
  Future<ConnectionRead> setCredentials({
    required String organizationId,
    required ConnectionRead connection,
    required PrinterCredentials credentials,
  }) async {
    final updated = await apiCall(
      () => _client.api.connections.updateConnection(
        orgId: organizationId,
        printerId: connection.printerId,
        connectionId: connection.id,
        body: ConnectionUpdate(
          credentials: ConnectionCredentialsInput(
            username: credentials.userName,
            password: credentials.password,
          ),
        ),
      ),
    );
    // What this phone kept is out of date now.
    final kept = await _keptCredentials(organizationId);
    kept[connection.id] = {
      'u': credentials.userName,
      'p': credentials.password,
    };
    await _store.write(_credentialsKey(organizationId), jsonEncode(kept));
    return updated;
  }

  Future<PrinterRead> rename({
    required String organizationId,
    required String printerId,
    required String name,
    String? location,
  }) {
    return apiCall(
      () => _client.api.printers.updatePrinter(
        orgId: organizationId,
        printerId: printerId,
        body: PrinterUpdate(friendlyName: name, location: location),
      ),
    );
  }

  Future<void> remove({
    required String organizationId,
    required String printerId,
  }) {
    return apiCall(
      () => _client.api.printers.removePrinter(
        orgId: organizationId,
        printerId: printerId,
      ),
    );
  }

  /// Forgets every kept list. Call when the user signs out.
  Future<void> clear(Iterable<String> organizationIds) async {
    for (final id in organizationIds) {
      await _store.delete(_cacheKey(id));
      await _store.delete(_credentialsKey(id));
    }
  }

  Future<PrinterRead?> _report(
    String organizationId,
    PrinterRead printer,
    DeviceStatus status,
  ) async {
    try {
      return await apiCall(
        () => _client.api.printers.reportStatus(
          orgId: organizationId,
          printerId: printer.id,
          body: statusToApi(status),
        ),
      );
    } on ApiException {
      // The status is still shown on this device. It reaches the backend
      // the next time it is read.
      return null;
    }
  }

  Future<void> _keep(String organizationId, List<PrinterRead> printers) {
    return _store.write(
      _cacheKey(organizationId),
      jsonEncode([for (final printer in printers) printer.toJson()]),
    );
  }

  Future<List<PrinterRead>?> _kept(String organizationId) async {
    final json = await _store.read(_cacheKey(organizationId));
    if (json == null) return null;
    try {
      return [
        for (final item in jsonDecode(json) as List<dynamic>)
          PrinterRead.fromJson(item as Map<String, dynamic>),
      ];
    } on Object {
      // Written by an older version of the app.
      return null;
    }
  }
}

/// A print in progress on one of the workspace's printers.
class PrinterPrint {
  new _(this._run, this._connectionIds);

  final PrintRun _run;
  final Map<DeviceConnection, String> _connectionIds;

  /// Each step of the print, ending with one that is final.
  Stream<PrintProgress> get progress => _run.progress;

  /// Stops the print, on the printer when it already has the job.
  Future<void> cancel() => _run.cancel();

  /// Which saved connection [connection] is, for the job's record.
  String? connectionIdOf(DeviceConnection? connection) =>
      _connectionIds[connection];
}

/// A scan in progress on a saved printer.
class PrinterScan {
  new _(this._run, this._connectionIds);

  final ScanRun _run;
  final Map<DeviceConnection, String> _connectionIds;

  /// Each step of the scan, ending with one that is final.
  Stream<ScanProgress> get progress => _run.progress;

  /// Stops the scan. The pages that have arrived are kept.
  Future<void> cancel() => _run.cancel();

  /// Which saved connection [connection] is, for the job's record.
  String? connectionIdOf(DeviceConnection? connection) =>
      _connectionIds[connection];
}
