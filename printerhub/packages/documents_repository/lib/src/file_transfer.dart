import 'dart:io';

/// A file could not be sent to, or fetched from, the storage.
class TransferFailed implements Exception {
  const new(this.reason, {this.statusCode});

  final String reason;

  /// What the storage answered, when it answered.
  final int? statusCode;

  @override
  String toString() {
    final answered = statusCode == null ? '' : ', HTTP $statusCode';
    return 'TransferFailed($reason$answered)';
  }
}

/// Moves files between the phone and the workspace's storage, over links
/// the API has signed.
abstract interface class FileTransfer {
  /// Sends [file] to [url]. [headers] go as they are: the link's signature
  /// covers them.
  Future<void> upload(
    Uri url, {
    required File file,
    String method,
    Map<String, String> headers,
  });

  /// Fetches what is at [url] into [into].
  Future<void> download(Uri url, {required File into});
}

/// Moves files with the phone's own HTTP client, a piece at a time, so a
/// large scan never sits in memory. Nothing of the account goes with them.
class IoFileTransfer implements FileTransfer {
  new({HttpClient? client, this.timeout = const Duration(minutes: 5)})
    : _client = client ?? HttpClient();

  final HttpClient _client;

  /// How long one transfer may take.
  final Duration timeout;

  @override
  Future<void> upload(
    Uri url, {
    required File file,
    String method = 'PUT',
    Map<String, String> headers = const {},
  }) async {
    try {
      final request = await _client.openUrl(method, url);
      headers.forEach(request.headers.set);
      request.contentLength = await file.length();
      await request.addStream(file.openRead());
      final response = await request.close().timeout(timeout);
      await response.drain<void>();
      if (response.statusCode >= 300) {
        throw TransferFailed(
          'The storage refused the file.',
          statusCode: response.statusCode,
        );
      }
    } on TransferFailed {
      rethrow;
    } on Object catch (error) {
      throw TransferFailed('$error');
    }
  }

  @override
  Future<void> download(Uri url, {required File into}) async {
    try {
      final request = await _client.getUrl(url);
      final response = await request.close().timeout(timeout);
      if (response.statusCode >= 300) {
        await response.drain<void>();
        throw TransferFailed(
          'The storage refused to give the file.',
          statusCode: response.statusCode,
        );
      }
      await response.pipe(into.openWrite());
    } on TransferFailed {
      rethrow;
    } on Object catch (error) {
      // Half a file is no file.
      if (into.existsSync()) into.deleteSync();
      throw TransferFailed('$error');
    }
  }

  void close() => _client.close(force: true);
}
