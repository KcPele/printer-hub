import 'dart:async';

import 'package:printer_protocols/src/http/printer_http.dart';
import 'package:printer_protocols/src/ipp/ipp_codec.dart';
import 'package:printer_protocols/src/ipp/ipp_constants.dart';
import 'package:printer_protocols/src/ipp/ipp_message.dart';
import 'package:printer_protocols/src/ipp/ipp_models.dart';

/// The printer understood the request and refused it, or failed.
class IppException implements Exception {
  const new(this.statusCode, [this.message]);

  /// One of [IppStatus].
  final int statusCode;

  /// What the printer said about it, when it said anything.
  final String? message;

  String get statusName => IppStatus.nameOf(statusCode);

  /// True when the request itself was wrong, so sending it again, or to
  /// another connection of the same printer, will fail the same way.
  bool get isClientError => statusCode >= 0x0400 && statusCode < 0x0500;

  @override
  String toString() =>
      'IppException($statusName${message == null ? '' : ': $message'})';
}

/// Something answered at the address, but not with IPP: the wrong path, a
/// printer that wants a secure connection, or one that wants a password.
class IppNotAvailable implements Exception {
  const new(this.uri, this.httpStatus);

  final Uri uri;
  final int httpStatus;

  /// True when the printer asked for a user name and password.
  bool get needsAuthentication => httpStatus == 401;

  /// True when the printer only accepts IPP over TLS.
  bool get needsTls => httpStatus == 426;

  @override
  String toString() => 'IppNotAvailable($uri answered HTTP $httpStatus)';
}

/// Sends IPP operations to one printer.
class IppClient {
  /// [printerUri] may use `ipp`, `ipps`, `http`, or `https`.
  new({
    required this.printerUri,
    required this._http,
    this.userName = 'PrinterHub',
  });

  /// The usual place a printer listens for IPP on [host].
  factory forHost(
    String host, {
    required PrinterHttp http,
    int port = 631,
    bool secure = false,
    String path = '/ipp/print',
  }) {
    return IppClient(
      printerUri: Uri(
        scheme: secure ? 'ipps' : 'ipp',
        host: host,
        port: port,
        path: path,
      ),
      http: http,
    );
  }

  final Uri printerUri;

  /// Shown on the printer's panel and in its job log.
  final String userName;
  final PrinterHttp _http;
  int _requestId = 0;

  /// The `ipp://` or `ipps://` form, which goes inside the message.
  Uri get _ippUri => printerUri.replace(
    scheme: switch (printerUri.scheme) {
      'http' => 'ipp',
      'https' => 'ipps',
      _ => printerUri.scheme,
    },
  );

  /// The `http://` or `https://` form, which the request is sent to.
  Uri get _httpUri {
    final secure = printerUri.scheme == 'ipps' || printerUri.scheme == 'https';
    return printerUri.replace(
      scheme: secure ? 'https' : 'http',
      port: printerUri.hasPort ? printerUri.port : 631,
    );
  }

  /// Asks the printer about itself. [requested] limits the answer to those
  /// attributes; null asks for everything.
  Future<IppPrinterAttributes> getPrinterAttributes({
    List<String>? requested,
  }) async {
    final response = await _send(
      IppOperation.getPrinterAttributes,
      operation: [
        if (requested != null)
          IppAttribute.all(
            'requested-attributes',
            IppValueTag.keyword,
            requested,
          ),
      ],
    );
    return IppPrinterAttributes(
      response.group(IppGroupTag.printer) ?? IppGroup(IppGroupTag.printer),
    );
  }

  /// Checks that the printer would accept a job with [options], without
  /// printing anything. Throws [IppException] when it would not.
  Future<void> validateJob(IppJobOptions options) async {
    await _send(
      IppOperation.validateJob,
      operation: _documentAttributes(options),
      job: options.toJobAttributes(),
    );
  }

  /// Sends [document] to be printed and returns the job the printer made.
  ///
  /// The document is streamed, never held in memory. Pass [length] when it
  /// is known, so the printer is told the size up front.
  Future<IppJob> printJob({
    required Stream<List<int>> document,
    required IppJobOptions options,
    int? length,
  }) async {
    final response = await _send(
      IppOperation.printJob,
      operation: _documentAttributes(options),
      job: options.toJobAttributes(),
      document: document,
      documentLength: length,
    );
    return _job(response);
  }

  Future<IppJob> getJobAttributes(int jobId) async {
    return _job(
      await _send(IppOperation.getJobAttributes, operation: [_id(jobId)]),
    );
  }

  /// The printer's jobs: those still running, or with [completed] those
  /// that have finished.
  Future<List<IppJob>> getJobs({bool completed = false}) async {
    final response = await _send(
      IppOperation.getJobs,
      operation: [
        IppAttribute.single(
          'which-jobs',
          IppValueTag.keyword,
          completed ? 'completed' : 'not-completed',
        ),
        IppAttribute.all('requested-attributes', IppValueTag.keyword, const [
          'job-id',
          'job-uri',
          'job-state',
          'job-state-reasons',
          'job-name',
        ]),
      ],
    );
    return response.groupsOf(IppGroupTag.job).map(IppJob.fromGroup).toList();
  }

  Future<void> cancelJob(int jobId) async {
    await _send(IppOperation.cancelJob, operation: [_id(jobId)]);
  }

  IppAttribute _id(int jobId) {
    return IppAttribute.single('job-id', IppValueTag.integer, jobId);
  }

  List<IppAttribute> _documentAttributes(IppJobOptions options) => [
    if (options.jobName != null)
      IppAttribute.single('job-name', IppValueTag.name, options.jobName),
    IppAttribute.single(
      'document-format',
      IppValueTag.mimeMediaType,
      options.documentFormat,
    ),
  ];

  IppJob _job(IppMessage response) {
    return IppJob.fromGroup(
      response.group(IppGroupTag.job) ?? IppGroup(IppGroupTag.job),
    );
  }

  Future<IppMessage> _send(
    int operationId, {
    List<IppAttribute> operation = const [],
    List<IppAttribute> job = const [],
    Stream<List<int>>? document,
    int? documentLength,
  }) async {
    final header = encodeIpp(
      IppMessage(
        code: operationId,
        requestId: ++_requestId,
        groups: [
          IppGroup(IppGroupTag.operation, [
            // These three come first, in this order. Printers insist on it.
            IppAttribute.single(
              'attributes-charset',
              IppValueTag.charset,
              'utf-8',
            ),
            IppAttribute.single(
              'attributes-natural-language',
              IppValueTag.naturalLanguage,
              'en',
            ),
            IppAttribute.single(
              'printer-uri',
              IppValueTag.uri,
              _ippUri.toString(),
            ),
            IppAttribute.single(
              'requesting-user-name',
              IppValueTag.name,
              userName,
            ),
            ...operation,
          ]),
          if (job.isNotEmpty) IppGroup(IppGroupTag.job, job),
        ],
      ),
    );

    Stream<List<int>> body() async* {
      yield header;
      if (document != null) yield* document;
    }

    final uri = _httpUri;
    final response = await _http.send(
      'POST',
      uri,
      headers: const {'Content-Type': 'application/ipp'},
      body: body(),
      contentLength: document == null
          ? header.length
          : documentLength == null
          ? null
          : header.length + documentLength,
    );
    if (response.statusCode != 200) {
      await response.body.drain<void>();
      throw IppNotAvailable(uri, response.statusCode);
    }

    final IppMessage message;
    try {
      message = decodeIpp(await response.bytes()).message;
    } on IppFormatException {
      // HTTP 200 with something that is not IPP: a web page at this path.
      throw IppNotAvailable(uri, response.statusCode);
    }
    if (message.code > IppStatus.lastSuccess) {
      final text = message.group(IppGroupTag.operation)?['status-message'];
      throw IppException(message.code, text?.first as String?);
    }
    return message;
  }
}
