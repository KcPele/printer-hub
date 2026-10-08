/// A stand-in for the workspace's storage, for tests.
library;

import 'dart:io';

import 'package:documents_repository/documents_repository.dart';

/// Keeps what is sent to it in memory, by the path of the link, and gives
/// it back.
class FakeFileTransfer implements FileTransfer {
  /// What the storage holds, by the path of the link it was sent to.
  final Map<String, List<int>> stored = {};

  /// Each upload as it was asked for.
  final List<({Uri url, String method, Map<String, String> headers})> uploads =
      [];

  /// True makes every transfer fail, as with no connection.
  bool broken = false;

  @override
  Future<void> upload(
    Uri url, {
    required File file,
    String method = 'PUT',
    Map<String, String> headers = const {},
  }) async {
    if (broken) throw const TransferFailed('No connection.');
    uploads.add((url: url, method: method, headers: headers));
    stored[url.path] = await file.readAsBytes();
  }

  @override
  Future<void> download(Uri url, {required File into}) async {
    final bytes = stored[url.path];
    if (broken || bytes == null) {
      throw const TransferFailed('Nothing there.', statusCode: 404);
    }
    await into.writeAsBytes(bytes);
  }
}
