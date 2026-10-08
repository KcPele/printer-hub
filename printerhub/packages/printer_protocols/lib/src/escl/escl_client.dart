import 'dart:convert';

import 'package:meta/meta.dart';
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

/// A scan the scanner has agreed to make.
class EsclScan {
  new({required this.uri, required this.fromFeeder});

  /// Where its pages are fetched from, and where it is cancelled.
  final Uri uri;
  final bool fromFeeder;

  /// How many pages have been handed over so far.
  int pagesReceived = 0;

  /// Runs from when the last page was asked for.
  final Stopwatch _sinceLastPage = Stopwatch();
}

/// Things particular scanners need done differently. The list is the one
/// the SANE project's `sane-airscan` driver has gathered from scanners in
/// use; see `docs/printer-compatibility.md`.
@immutable
class EsclQuirks {
  const new({
    this.retryWhenNotFound = false,
    this.statusBeforeNextPage = false,
    this.pauseBetweenPages = false,
    this.localhostHostHeader = false,
  });

  /// What the scanner called [makeAndModel] needs.
  factory forModel(String? makeAndModel) {
    final model = makeAndModel?.trim() ?? '';
    final lower = model.toLowerCase();
    return EsclQuirks(
      // Xerox B205 and B215 answer "not found" while a page is still on
      // its way, where others answer "busy".
      retryWhenNotFound: const {
        'B205',
        'B215',
        'WorkCentre 3345',
      }.contains(model),
      // Some Ricoh scanners leave the job pending until asked how they are.
      statusBeforeNextPage: model == 'RICOH',
      // Brother feeders lose pages when asked for the next one at once.
      pauseBetweenPages: lower.startsWith('brother '),
      // These HP models refuse a scan addressed to them by anything else.
      localhostHostHeader: const {
        'HP LaserJet MFP M630',
        'HP Color LaserJet FlowMFP M578',
      }.contains(model),
    );
  }

  static const EsclQuirks none = EsclQuirks();

  final bool retryWhenNotFound;
  final bool statusBeforeNextPage;
  final bool pauseBetweenPages;
  final bool localhostHostHeader;
}

/// Sends eSCL (AirScan) requests to one scanner.
class EsclClient {
  /// [baseUri] is the scanner's eSCL root, usually `http://<host>/eSCL`.
  ///
  /// A scanner that is warming up or still moving its lamp answers "busy".
  /// It is asked again after [retryPause], up to [startAttempts] times to
  /// begin a scan and [pageAttempts] times for a page. [pause] is how the
  /// client waits; tests pass their own.
  new({
    required Uri baseUri,
    required this._http,
    this.quirks = EsclQuirks.none,
    this.retryPause = const Duration(seconds: 1),
    this.startAttempts = 10,
    this.pageAttempts = 30,
    Future<void> Function(Duration)? pause,
  }) : baseUri = baseUri.replace(
         path: baseUri.path.replaceFirst(RegExp(r'/+$'), ''),
       ),
       _pause = pause ?? Future<void>.delayed;

  /// The usual place a scanner offers eSCL on [host].
  factory forHost(
    String host, {
    required PrinterHttp http,
    int port = 80,
    bool secure = false,
    EsclQuirks quirks = EsclQuirks.none,
  }) {
    return EsclClient(
      baseUri: Uri(
        scheme: secure ? 'https' : 'http',
        host: host,
        port: port,
        path: '/eSCL',
      ),
      http: http,
      quirks: quirks,
    );
  }

  final Uri baseUri;
  final EsclQuirks quirks;
  final Duration retryPause;
  final int startAttempts;
  final int pageAttempts;
  final PrinterHttp _http;
  final Future<void> Function(Duration) _pause;

  Uri _at(String path) => baseUri.replace(path: '${baseUri.path}/$path');

  Future<EsclCapabilities> capabilities() async {
    final xml = await _text(_at('ScannerCapabilities'));
    return _parse<EsclCapabilities>(xml, EsclCapabilities.parse);
  }

  Future<EsclStatus> status() async {
    final xml = await _text(_at('ScannerStatus'));
    return _parse<EsclStatus>(xml, EsclStatus.parse);
  }

  /// Starts a scan.
  Future<EsclScan> startScan(EsclScanSettings settings) async {
    final body = utf8.encode(settings.toXml());
    for (var attempt = 1; ; attempt++) {
      final response = await _http.send(
        'POST',
        _at('ScanJobs'),
        headers: {
          'Content-Type': 'text/xml',
          if (quirks.localhostHostHeader) 'Host': 'localhost',
        },
        body: Stream.value(body),
        contentLength: body.length,
      );
      final message = await _drain(response);
      if (response.statusCode == 503 && attempt < startAttempts) {
        await _pause(retryPause);
        continue;
      }
      final location = response.headers['location'];
      if (response.statusCode != 201 || location == null || location.isEmpty) {
        throw EsclException(response.statusCode, message);
      }
      return EsclScan(uri: _jobUri(location), fromFeeder: settings.fromFeeder);
    }
  }

  /// Where the job is, from the `Location` the scanner answered with.
  ///
  /// Only its path is believed. A scanner does not reliably know its own
  /// name: some answer with a host the phone cannot find, and some with an
  /// address cut short. The job is on the device the request went to.
  Uri _jobUri(String location) {
    var path = location;
    final scheme = location.indexOf('://');
    if (scheme >= 0) {
      final slash = location.indexOf('/', scheme + 3);
      path = slash < 0 ? '' : location.substring(slash);
    } else if (!location.startsWith('/')) {
      path = '${baseUri.path}/ScanJobs/$location';
    }
    final end = path.indexOf(RegExp('[?#]'));
    if (end >= 0) path = path.substring(0, end);
    return baseUri.replace(path: path.replaceFirst(RegExp(r'/+$'), ''));
  }

  /// The next page of [scan], or null when there are no more.
  ///
  /// A scan from the glass has one. A scan from the feeder has one per
  /// sheet: call this until it returns null, then [cancel] to let the
  /// scanner forget the job.
  Future<EsclDocument?> nextDocument(EsclScan scan) async {
    // The glass gives one page. Once it is here, anything but another page
    // is the end, and there is nothing to wait for.
    final done = !scan.fromFeeder && scan.pagesReceived > 0;
    final uri = scan.uri.replace(path: '${scan.uri.path}/NextDocument');

    if (quirks.pauseBetweenPages && scan.fromFeeder && scan.pagesReceived > 0) {
      // Half the time the last page took, and no more than one pause.
      final half = scan._sinceLastPage.elapsed ~/ 2;
      await _pause(half > retryPause ? retryPause : half);
    }
    scan._sinceLastPage
      ..reset()
      ..start();

    if (quirks.statusBeforeNextPage) {
      try {
        await status();
      } on EsclException {
        // Asked for the scanner's sake; the answer does not matter.
      }
    }

    for (var attempt = 1; ; attempt++) {
      final response = await _http.send('GET', uri);
      final code = response.statusCode;
      if (code == 200) {
        scan.pagesReceived++;
        return EsclDocument(
          bytes: response.body,
          contentType: response.headers['content-type'],
        );
      }

      final message = await _drain(response);
      final gone = code == 404 || code == 410;
      final busy = code == 503 || (gone && quirks.retryWhenNotFound);
      if (busy && !done && attempt < pageAttempts) {
        await _pause(retryPause);
        continue;
      }
      // After a page, or from a feeder, "not found" is how a scanner says
      // there are no more. From the glass with nothing yet, the job failed.
      if (done || (gone && (scan.fromFeeder || scan.pagesReceived > 0))) {
        return null;
      }
      throw EsclException(code, message);
    }
  }

  /// Ends [scan], whether it is running or finished. A job the scanner has
  /// already forgotten is not an error.
  Future<void> cancel(EsclScan scan) async {
    final response = await _http.send('DELETE', scan.uri);
    final message = await _drain(response);
    if (response.statusCode >= 400 &&
        response.statusCode != 404 &&
        response.statusCode != 410) {
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
