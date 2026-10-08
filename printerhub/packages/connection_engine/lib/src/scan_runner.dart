import 'dart:async';
import 'dart:io';

import 'package:connection_engine/src/device.dart';
import 'package:equatable/equatable.dart';
import 'package:printer_protocols/printer_protocols.dart';

/// What to scan and how. The scanner is asked for the nearest it offers.
class ScanRequest extends Equatable {
  const new({
    this.source = 'platen',
    this.color = true,
    this.duplex = false,
    this.resolutionDpi = 300,
    this.format = 'image/jpeg',
    this.widthMm = 210,
    this.heightMm = 297,
  });

  /// `platen` for the glass, `adf` for the document feeder.
  final String source;

  /// False scans in grey.
  final bool color;

  /// Both sides of each sheet. Only from a feeder that can.
  final bool duplex;
  final int resolutionDpi;

  /// The form each page arrives in: `image/jpeg` or `application/pdf`.
  final String format;

  /// The area to scan, from the top left corner. A4 by default.
  final double widthMm;
  final double heightMm;

  bool get fromFeeder => source == 'adf';

  @override
  List<Object?> get props => [
    source,
    color,
    duplex,
    resolutionDpi,
    format,
    widthMm,
    heightMm,
  ];
}

/// One page as the scanner delivered it, kept in a file.
class ScannedPage extends Equatable {
  const new({required this.file, required this.mimeType});

  final File file;

  /// `image/jpeg` or `application/pdf`.
  final String mimeType;

  @override
  List<Object?> get props => [file.path, mimeType];
}

enum ScanStage {
  /// Reaching the scanner and asking what it can do.
  connecting,

  /// The scanner has the job, and pages are arriving.
  scanning,

  completed,
  failed,
  cancelled,
}

/// Where a scan has got to.
class ScanProgress extends Equatable {
  const new(
    this.stage, {
    this.connection,
    this.pages = const [],
    this.errorCode,
    this.errorMessage,
  });

  final ScanStage stage;

  /// The connection in use.
  final DeviceConnection? connection;

  /// The pages that have arrived so far, in order. A scan that fails or is
  /// cancelled keeps the ones it got.
  final List<ScannedPage> pages;

  /// Why it failed: `scan.unreachable`, `scan.feeder_empty`,
  /// `escl.http_500`.
  final String? errorCode;

  /// What the scanner said about it, when it said anything.
  final String? errorMessage;

  /// True when nothing more will follow.
  bool get isFinal =>
      stage == ScanStage.completed ||
      stage == ScanStage.failed ||
      stage == ScanStage.cancelled;

  @override
  List<Object?> get props => [
    stage,
    connection,
    pages,
    errorCode,
    errorMessage,
  ];
}

/// Scans on a device the app has saved, over eSCL.
///
/// Each page goes to a file as it arrives, so a long scan never sits in
/// memory. The device's eSCL connections are tried in order, and the next
/// one only before the scanner has taken the job: a scan is never started
/// twice.
class ScanRunner {
  new({required this._http, Directory? directory, this._pause})
    : _directory = directory ?? Directory.systemTemp;

  final PrinterHttp _http;
  final Directory _directory;
  final Future<void> Function(Duration)? _pause;

  /// Starts a scan.
  ScanRun start({
    required List<DeviceConnection> connections,
    required ScanRequest request,
  }) {
    return ScanRun._(this, [
      for (final connection in connections)
        if (connection.type == 'escl') connection,
    ], request).._begin();
  }
}

/// One scan in progress.
class ScanRun {
  new _(this._runner, this._connections, this._request);

  final ScanRunner _runner;
  final List<DeviceConnection> _connections;
  final ScanRequest _request;

  final _progress = StreamController<ScanProgress>();
  final List<ScannedPage> _pages = [];
  bool _cancelled = false;
  DeviceConnection? _connection;
  EsclClient? _client;
  EsclScan? _scan;

  /// Each step of the scan, ending with one that [ScanProgress.isFinal].
  Stream<ScanProgress> get progress => _progress.stream;

  /// Stops the scan. The pages that have arrived are kept.
  Future<void> cancel() async {
    _cancelled = true;
    final client = _client;
    final scan = _scan;
    if (client != null && scan != null) await _forget(client, scan);
  }

  void _begin() => unawaited(_run().whenComplete(_progress.close));

  void _emit(ScanStage stage, {String? errorCode, String? errorMessage}) {
    _progress.add(
      ScanProgress(
        stage,
        connection: _connection,
        pages: List.unmodifiable(_pages),
        errorCode: errorCode,
        errorMessage: errorMessage,
      ),
    );
  }

  Future<void> _run() async {
    var failure = 'scan.no_connection';
    for (final connection in _connections) {
      if (_cancelled) return _emit(ScanStage.cancelled);
      _connection = connection;
      _emit(ScanStage.connecting);

      final next = await _attempt(connection);
      if (next == null) return;
      failure = next;
    }
    _emit(ScanStage.failed, errorCode: failure);
  }

  /// Tries one connection. Returns null when the scan ended here, one way
  /// or another, and the reason when the next connection should be tried.
  Future<String?> _attempt(DeviceConnection connection) async {
    var client = EsclClient(baseUri: connection.uri, http: _runner._http);
    EsclScan? scan;
    try {
      final offers = await client.capabilities();
      // The scanner has said what it is: some models need handling of
      // their own from here on.
      client = EsclClient(
        baseUri: connection.uri,
        http: _runner._http,
        quirks: EsclQuirks.forModel(offers.makeAndModel),
        pause: _runner._pause,
      );
      final input = _request.fromFeeder ? offers.feeder : offers.platen;
      if (input == null) {
        // No other connection gives the device a feeder.
        _emit(ScanStage.failed, errorCode: 'scan.source_not_available');
        return null;
      }
      final settings = input.settings(
        fromFeeder: _request.fromFeeder,
        color: _request.color,
        duplex: _request.duplex && offers.feederDuplex,
        resolutionDpi: _request.resolutionDpi,
        documentFormat: _request.format,
        widthMm: _request.widthMm,
        heightMm: _request.heightMm,
      );
      if (_cancelled) {
        _emit(ScanStage.cancelled);
        return null;
      }

      scan = await client.startScan(settings);
      _client = client;
      _scan = scan;
      _emit(ScanStage.scanning);

      while (!_cancelled) {
        final page = await client.nextDocument(scan);
        if (page == null) break;
        _pages.add(await _keep(page, settings.documentFormat));
        _emit(ScanStage.scanning);
      }
      await _forget(client, scan);

      if (_cancelled) {
        _emit(ScanStage.cancelled);
      } else if (_pages.isEmpty) {
        // A feeder with nothing in it, on a scanner that only says so now.
        _emit(ScanStage.failed, errorCode: 'scan.feeder_empty');
      } else {
        _emit(ScanStage.completed);
      }
      return null;
    } on EsclException catch (error) {
      if (_cancelled) {
        _emit(ScanStage.cancelled);
        return null;
      }
      if (scan == null && error.notSupported) {
        // eSCL is not at this address, or is switched off on it.
        return 'scan.not_available';
      }
      final code = await _why(client, error);
      if (scan != null) await _forget(client, scan);
      _emit(ScanStage.failed, errorCode: code, errorMessage: error.message);
      return null;
    } on FileSystemException catch (error) {
      await _forget(client, scan!);
      _emit(
        ScanStage.failed,
        errorCode: 'scan.storage',
        errorMessage: error.message,
      );
      return null;
    } on Object {
      if (_cancelled) {
        _emit(ScanStage.cancelled);
        return null;
      }
      // Nothing answered. Before the scanner took the job, another way of
      // reaching it may work; after, the scan is over.
      if (scan == null) return 'scan.unreachable';
      _emit(ScanStage.failed, errorCode: 'scan.connection_lost');
      return null;
    }
  }

  /// Writes one page to a file as it arrives.
  Future<ScannedPage> _keep(EsclDocument page, String askedFor) async {
    final answered = page.contentType?.split(';').first.trim().toLowerCase();
    final mimeType = answered == null || answered.isEmpty ? askedFor : answered;
    final file = File(
      '${_runner._directory.path}/scan-'
      '${DateTime.now().microsecondsSinceEpoch}-${_pages.length + 1}'
      '.${mimeType == 'application/pdf' ? 'pdf' : 'jpg'}',
    );
    final sink = file.openWrite();
    try {
      await sink.addStream(page.bytes);
      await sink.close();
    } on Object {
      // Half a page is no page.
      await sink.close().catchError((Object _) {});
      if (file.existsSync()) file.deleteSync();
      rethrow;
    }
    return ScannedPage(file: file, mimeType: mimeType);
  }

  /// Why the scanner refused, in the app's own codes. A scanner that says
  /// it is not ready is asked what is wrong with it.
  Future<String> _why(EsclClient client, EsclException error) async {
    if (error.busy) return 'scan.busy';
    if (!error.notReady) return 'escl.http_${error.httpStatus}';
    try {
      final status = await client.status();
      if (status.feederEmpty) return 'scan.feeder_empty';
      if (status.feederJammed) return 'scan.feeder_jam';
      if (status.feederOpen) return 'scan.feeder_open';
    } on Object {
      // It would not say.
    }
    return 'scan.not_ready';
  }

  /// Lets the scanner forget the job, finished or not.
  Future<void> _forget(EsclClient client, EsclScan scan) async {
    try {
      await client.cancel(scan);
    } on Object {
      // Already gone, or out of reach: there is nothing left to end.
    }
  }
}
