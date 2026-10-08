import 'dart:convert';

import 'package:api_client/api_client.dart';
import 'package:connection_engine/connection_engine.dart';
import 'package:local_store/local_store.dart';
import 'package:printers_repository/src/api_mapping.dart';

/// The printers of a workspace.
///
/// The list lives on the backend, so everyone in the workspace sees the same
/// printers. What a printer is doing comes from the device itself, over the
/// local network, and is reported back for the others to see.
class PrintersRepository {
  new({required this._client, required this._probe, required this._store});

  static const int _pageSize = 100;

  final PrinterHubClient _client;
  final DeviceProbe _probe;
  final SecureStore _store;

  static String _cacheKey(String organizationId) => 'printers.$organizationId';

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

  /// Asks the device at [address] what it is. Throws [ProbeFailure].
  Future<DeviceDescription> probe(String address) => _probe.probe(address);

  /// Asks a device that announced itself on the network what it is.
  /// Throws [ProbeFailure].
  Future<DeviceDescription> probeAnnounced({
    required String host,
    Uri? ipp,
    Uri? escl,
  }) {
    return _probe.probeAnnounced(host: host, ipp: ipp, escl: escl);
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
  }) async {
    final printer = await apiCall(
      () => _client.api.printers.addPrinter(
        orgId: organizationId,
        body: printerToApi(device, name: name, location: location),
      ),
    );
    // What the device said about itself while it was probed is worth
    // keeping; a failure to record it does not undo adding the printer.
    return await _report(organizationId, printer, device.status) ?? printer;
  }

  /// Asks the printer itself what it is doing, and tells the backend.
  ///
  /// Never throws for a device that does not answer: that is a status too.
  /// The returned printer is the backend's when it could be told, and the
  /// given one otherwise.
  Future<({PrinterRead printer, DeviceStatus status})> refreshStatus({
    required String organizationId,
    required PrinterRead printer,
  }) async {
    final status = await _probe.status([
      for (final connection in printer.connections)
        ?connectionFromApi(connection),
    ]);
    final reported = await _report(organizationId, printer, status);
    return (printer: reported ?? printer, status: status);
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
