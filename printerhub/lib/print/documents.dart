import 'dart:io';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:printers_repository/printers_repository.dart';

/// A file chosen to print.
class PickedDocument extends Equatable {
  const new({
    required this.name,
    required this.path,
    required this.length,
    required this.open,
  });

  /// A file already on the phone, such as a scan that was just saved or a
  /// document fetched from the workspace.
  factory fromFile(File file) {
    return PickedDocument(
      name: Uri.decodeComponent(file.uri.pathSegments.last),
      path: file.path,
      length: file.lengthSync(),
      open: file.openRead,
    );
  }

  /// The file's name, as it will show on the printer.
  final String name;

  /// Where the file is on the phone.
  final String path;

  /// Its size in bytes.
  final int length;

  /// Opens the file for reading, from the start, each time it is called.
  final Stream<List<int>> Function() open;

  /// What kind of file it is, from its name. Null for a kind the app does
  /// not print.
  String? get mimeType {
    final dot = name.lastIndexOf('.');
    return switch (dot < 0 ? '' : name.substring(dot + 1).toLowerCase()) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => null,
    };
  }

  @override
  List<Object> get props => [name, path, length];
}

/// What a document looks like, for showing before it is printed.
class DocumentPreview extends Equatable {
  const new({required this.pageCount, this.firstPage});

  final int pageCount;

  /// The first page as a PNG, small. Null when it could not be drawn.
  final Uint8List? firstPage;

  @override
  List<Object?> get props => [pageCount, firstPage];
}

/// Lets the person choose a file from the phone.
abstract interface class DocumentPicker {
  /// The chosen file, or null when they chose nothing.
  Future<PickedDocument?> pick();
}

/// Reads and draws documents. The drawing is done by the phone's own PDF
/// and image code, which only exists on a device.
abstract interface class PageRenderer {
  /// How many pages [document] has and what the first looks like. Throws
  /// when the file cannot be read as what it claims to be.
  Future<DocumentPreview> preview(PickedDocument document);

  /// Draws each page of [document] as the pixels of a [page], in order,
  /// for a printer that does not read the file itself.
  Stream<Uint8List> rasterise(PickedDocument document, RasterDocument page);

  /// Hands [document] to the phone's own print dialog. True when it was
  /// sent on from there.
  Future<bool> systemPrint(PickedDocument document);
}

/// The ways the app gets at documents, gathered so it can be given them in
/// one piece: the real ones on a phone, stand-ins in a test.
class PrintDocuments {
  const new({required this.picker, required this.renderer});

  final DocumentPicker picker;
  final PageRenderer renderer;
}

/// The files other apps hand to this one to print: shared to it, or
/// opened with it.
// One member, but a class so the app can be given a stand-in for it.
abstract interface class IncomingDocuments {
  /// Each file as it arrives. One that started the app is the first.
  Stream<PickedDocument> get documents;
}
