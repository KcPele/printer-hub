import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:printerhub/print/documents.dart';

/// A document that is open on the phone: its file, and what it is called.
///
/// Anything that has a file can open it by handing one of these to
/// `AppRoutes.documentView`: a kept document, a scan just saved, a page a
/// tool made. What can be done with it is decided there, in one place.
class OpenDocument extends Equatable {
  const new({required this.file, required this.name, required this.mimeType});

  final File file;

  /// Its file name, such as `Receipts.pdf`.
  final String name;
  final String mimeType;

  bool get isPdf => mimeType == 'application/pdf';
  bool get isPicture => mimeType.startsWith('image/');

  /// This, as the print screen and the tools take a file.
  PickedDocument get picked => PickedDocument(
    name: name,
    path: file.path,
    length: file.existsSync() ? file.lengthSync() : 0,
    open: file.openRead,
  );

  @override
  List<Object?> get props => [file.path, name, mimeType];
}
