import 'dart:convert';
import 'dart:typed_data';

import 'package:printerhub/print/print.dart';
import 'package:printers_repository/printers_repository.dart';

/// A PDF on the phone, as the file browser would hand it over.
PickedDocument pickedPdf({String name = 'Report.pdf'}) {
  final bytes = utf8.encode('%PDF-1.7 a report');
  return PickedDocument(
    name: name,
    path: '/documents/$name',
    length: bytes.length,
    open: () => Stream.value(bytes),
  );
}

/// Stands in for the phone's file browser. Chooses [next], or nothing when
/// it is null.
class FakeDocumentPicker implements DocumentPicker {
  PickedDocument? next = pickedPdf();
  int opened = 0;

  @override
  Future<PickedDocument?> pick() async {
    opened++;
    return next;
  }
}

/// Stands in for the phone's PDF and image code.
class FakePageRenderer implements PageRenderer {
  int pageCount = 2;

  /// The first page as a picture, when a test wants one shown.
  Uint8List? firstPage;

  /// True makes every file unreadable.
  bool unreadable = false;

  /// Whether the phone's print dialog sends the document on.
  bool systemAccepts = true;
  final List<PickedDocument> systemPrinted = [];
  int drawn = 0;

  @override
  Future<DocumentPreview> preview(PickedDocument document) async {
    if (unreadable) throw const FormatException('not a PDF');
    return DocumentPreview(pageCount: pageCount, firstPage: firstPage);
  }

  @override
  Stream<Uint8List> rasterise(
    PickedDocument document,
    RasterDocument page,
  ) async* {
    for (var i = 0; i < pageCount; i++) {
      drawn++;
      yield Uint8List(page.bytesPerPage)..fillRange(0, page.bytesPerPage, 255);
    }
  }

  @override
  Future<bool> systemPrint(PickedDocument document) async {
    systemPrinted.add(document);
    return systemAccepts;
  }
}
