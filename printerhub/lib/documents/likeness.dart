import 'dart:io';

import 'package:printerhub/print/documents.dart';

/// What [file] looks like, small: a picture is its own likeness, and a
/// PDF is its first page, drawn once and left at [kept] for next time.
/// Null for a file that cannot be drawn; it is shown by the sign for its
/// kind.
Future<File?> likenessOf(
  PageRenderer renderer,
  File file, {
  required String mimeType,
  required File kept,
}) async {
  if (mimeType.startsWith('image/')) return file;
  if (mimeType != 'application/pdf') return null;
  if (kept.existsSync()) return kept;
  try {
    final first = (await renderer.preview(PickedDocument.fromFile(file)))
        .firstPage;
    if (first == null) return null;
    kept.writeAsBytesSync(first, flush: true);
    return kept;
  } on Object {
    return null;
  }
}
