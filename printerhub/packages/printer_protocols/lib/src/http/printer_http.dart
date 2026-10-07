import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// The device did not answer: it is off, on another network, refused the
/// connection, timed out, or presented a certificate that was not accepted.
class PrinterUnreachable implements Exception {
  const new(this.uri, this.cause);

  final Uri uri;
  final Object cause;

  @override
  String toString() => 'PrinterUnreachable($uri: $cause)';
}

/// An HTTP answer from a device.
class PrinterHttpResponse {
  const new({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;

  /// Header names are lower case.
  final Map<String, String> headers;

  /// The body, as it arrives. Listen once.
  final Stream<List<int>> body;

  /// Reads the whole body into memory. Use for small answers only; a scanned
  /// page is streamed to a file instead.
  Future<Uint8List> bytes() async {
    final builder = BytesBuilder(copy: false);
    await body.forEach(builder.add);
    return builder.takeBytes();
  }
}

/// Decides whether to talk to a device whose certificate is not signed by a
/// known authority, which is every printer. [fingerprint] is the SHA-256 of
/// the certificate, in hex.
typedef CertificateCheck = bool Function(
  String host,
  int port,
  String fingerprint,
);

/// How the protocol clients reach a device. Tests supply their own.
abstract interface class PrinterHttp {
  /// Sends one request. Throws [PrinterUnreachable] when there is no answer.
  Future<PrinterHttpResponse> send(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    Stream<List<int>>? body,
    int? contentLength,
  });

  void close();
}

/// Reaches devices over the network.
class IoPrinterHttp implements PrinterHttp {
  /// Without [certificateCheck], a device with a self-signed certificate is
  /// refused. Certificate checking is never switched off for everything.
  new({
    Duration connectTimeout = const Duration(seconds: 5),
    this.responseTimeout = const Duration(seconds: 30),
    CertificateCheck? certificateCheck,
  }) : _client = HttpClient()..connectionTimeout = connectTimeout {
    if (certificateCheck != null) {
      _client.badCertificateCallback = (certificate, host, port) {
        return certificateCheck(host, port, fingerprintOf(certificate.der));
      };
    }
  }

  /// How long to wait for the device to start answering.
  final Duration responseTimeout;
  final HttpClient _client;

  /// The SHA-256 of a certificate, in lower-case hex.
  static String fingerprintOf(List<int> der) => sha256.convert(der).toString();

  @override
  Future<PrinterHttpResponse> send(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    Stream<List<int>>? body,
    int? contentLength,
  }) async {
    try {
      final request = await _client.openUrl(method, uri);
      headers.forEach(request.headers.set);
      if (contentLength != null) request.contentLength = contentLength;
      if (body != null) await request.addStream(body);

      final response = await request.close().timeout(responseTimeout);
      final answered = <String, String>{};
      response.headers.forEach((name, values) {
        answered[name.toLowerCase()] = values.join(', ');
      });
      return PrinterHttpResponse(
        statusCode: response.statusCode,
        headers: answered,
        body: response,
      );
    } on IOException catch (error) {
      throw PrinterUnreachable(uri, error);
    } on TimeoutException catch (error) {
      throw PrinterUnreachable(uri, error);
    }
  }

  @override
  void close() => _client.close(force: true);
}
