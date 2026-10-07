import 'dart:convert';

import 'package:printer_protocols/src/escl/escl_models.dart';
import 'package:printer_protocols/src/http/printer_http.dart';
import 'package:xml/xml.dart';

/// The scanner answered with an error.
class EsclException implements Exception {
  const new(this.httpStatus, [this.message]);

  final int httpStatus;
  final String? message;

  /// The device does not offer eSCL here. Some firmware has it switched off.
  bool get notSupported => httpStatus == 404;

  /// A scan is already running, or the scanner is warming up.
  bool get busy => httpStatus == 503;

  /// The scanner cannot do this now: the feeder is empty or jammed.
  bool get notReady => httpStatus == 409;

  @override
  String toString() =>
      'EsclException(HTTP $httpStatus${message == null ? '' : ': $message'})';
}

/// One scanned page, or one whole document when the format holds several
/// pages.
class EsclDocument {
  const new({required this.bytes, this.contentType});

  /// The page as it arrives. Write it to a file as it comes; a page can be
  /// tens of megabytes.
  final Stream<List<int>> bytes;
  final String? contentType;
}

/// Sends eSCL (AirScan) requests to one scanner.
class EsclClient {
  /// [baseUri] is the scanner's eSCL root, usually `http://<host>/eSCL`.
  new({required Uri baseUri, required this._http})
    : baseUri = baseUri.replace(
        path: baseUri.path.replaceFirst(RegExp(r'/+$'), ''),
      );

  /// The usual place a scanner offers eSCL on [host].
  factory forHost(
    String host, {
    required PrinterHttp http,
    int port = 80,
    bool secure = false,
  }) {
    return EsclClient(
      baseUri: Uri(
        scheme: secure ? 'https' : 'http',
        host: host,
        port: port,
        path: '/eSCL',
      ),
      http: http,
    );
  }

  final Uri baseUri;
  final PrinterHttp _http;

  Uri _at(String path) => baseUri.replace(path: '${baseUri.path}/$path');

  Future<EsclCapabilities> capabilities() async {
    final xml = await _text(_at('ScannerCapabilities'));
    return _parse<EsclCapabilities>(xml, EsclCapabilities.parse);
  }

  Future<EsclStatus> status() async {
    final xml = await _text(_at('ScannerStatus'));
    return _parse<EsclStatus>(xml, EsclStatus.parse);
  }

  /// Starts a scan and returns where its pages are fetched from.
  Future<Uri> startScan(EsclScanSettings settings) async {
    final body = utf8.encode(settings.toXml());
    final response = await _http.send(
      'POST',
      _at('ScanJobs'),
      headers: const {'Content-Type': 'text/xml'},
      body: Stream.value(body),
      contentLength: body.length,
    );
    final message = await _drain(response);
    final location = response.headers['location'];
    if (response.statusCode != 201 || location == null) {
      throw EsclException(response.statusCode, message);
    }
    // Some scanners answer with a path, others with a full address.
    return baseUri.resolve(location);
  }

  /// The next page of [job], or null when there are no more.
  ///
  /// A scan from the glass has one. A scan from the feeder has one per
  /// sheet: call this until it returns null.
  Future<EsclDocument?> nextDocument(Uri job) async {
    final response = await _http.send(
      'GET',
      job.replace(path: '${job.path}/NextDocument'),
    );
    if (response.statusCode == 404) {
      await response.body.drain<void>();
      return null;
    }
    if (response.statusCode != 200) {
      throw EsclException(response.statusCode, await _drain(response));
    }
    return EsclDocument(
      bytes: response.body,
      contentType: response.headers['content-type'],
    );
  }

  /// Stops [job]. A job that has already ended is not an error.
  Future<void> cancel(Uri job) async {
    final response = await _http.send('DELETE', job);
    final message = await _drain(response);
    if (response.statusCode >= 400 && response.statusCode != 404) {
      throw EsclException(response.statusCode, message);
    }
  }

  Future<String> _text(Uri uri) async {
    final response = await _http.send('GET', uri);
    final body = await _drain(response);
    if (response.statusCode != 200) {
      throw EsclException(response.statusCode, body);
    }
    return body ?? '';
  }

  /// A device that answers 200 with something other than the expected
  /// document, such as its home page, does not offer eSCL here.
  T _parse<T>(String xml, T Function(String xml) parse) {
    try {
      return parse(xml);
    } on XmlException {
      throw const EsclException(404, 'The answer was not an eSCL document.');
    }
  }

  Future<String?> _drain(PrinterHttpResponse response) async {
    final text = utf8.decode(await response.bytes(), allowMalformed: true);
    return text.trim().isEmpty ? null : text.trim();
  }
}
