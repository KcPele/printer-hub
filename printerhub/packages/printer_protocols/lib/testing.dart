// Test support is not part of what the package ships to users.
// coverage:ignore-file

/// A stand-in for a device, for tests of anything built on the protocol
/// clients.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:printer_protocols/printer_protocols.dart';

/// One request a [FakePrinterHttp] received, with its body read in full.
class SentRequest {
  const new(this.method, this.uri, this.headers, this.body, this.contentLength);

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final Uint8List body;
  final int? contentLength;

  String get text => utf8.decode(body);
}

/// What a [FakePrinterHttp] answers with.
class FakeAnswer {
  const new(this.statusCode, {this.body = const [], this.headers = const {}});

  new text(this.statusCode, String text, {this.headers = const {}})
    : body = utf8.encode(text);

  /// An IPP response in an HTTP 200.
  new ipp(IppMessage message)
    : statusCode = 200,
      body = encodeIpp(message),
      headers = const {'content-type': 'application/ipp'};

  final int statusCode;
  final List<int> body;
  final Map<String, String> headers;
}

typedef FakeDevice = FutureOr<FakeAnswer> Function(SentRequest request);

/// Answers from [device] instead of the network, and keeps what was sent.
class FakePrinterHttp implements PrinterHttp {
  new(this.device);

  FakeDevice device;
  final List<SentRequest> requests = [];
  bool closed = false;

  @override
  Future<PrinterHttpResponse> send(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    Stream<List<int>>? body,
    int? contentLength,
  }) async {
    final bytes = BytesBuilder();
    if (body != null) await body.forEach(bytes.add);
    final request = SentRequest(
      method,
      uri,
      headers,
      bytes.takeBytes(),
      contentLength,
    );
    requests.add(request);

    final answer = await device(request);
    return PrinterHttpResponse(
      statusCode: answer.statusCode,
      headers: answer.headers,
      body: Stream.value(answer.body),
    );
  }

  @override
  void close() => closed = true;
}

/// An IPP response with [status] and the given groups.
IppMessage ippResponse({
  int status = IppStatus.ok,
  int requestId = 1,
  List<IppGroup> groups = const [],
  String? statusMessage,
}) {
  return IppMessage(
    code: status,
    requestId: requestId,
    groups: [
      IppGroup(IppGroupTag.operation, [
        IppAttribute.single('attributes-charset', IppValueTag.charset, 'utf-8'),
        IppAttribute.single(
          'attributes-natural-language',
          IppValueTag.naturalLanguage,
          'en',
        ),
        if (statusMessage != null)
          IppAttribute.single(
            'status-message',
            IppValueTag.text,
            statusMessage,
          ),
      ]),
      ...groups,
    ],
  );
}
