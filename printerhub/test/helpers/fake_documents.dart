import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:printerhub/print/print.dart';
import 'package:printerhub/scan/scan.dart';
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

/// A small picture, as a scanner would deliver a page: a JPEG two pixels
/// square.
final Uint8List tinyJpeg = base64Decode(
  '/9j/4AAQSkZJRgABAQAASABIAAD/wAALCAACAAIBAREA/8QAHwAAAQUBAQEBAQEAAAAAAAAA'
  'AAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKB'
  'kaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNk'
  'ZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXG'
  'x8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/9sAQwAGBgYGBgYKBgYKDgoKCg4S'
  'Dg4ODhIXEhISEhIXHBcXFxcXFxwcHBwcHBwcIiIiIiIiJycnJycsLCwsLCwsLCws/90ABAAB'
  '/9oACAEBAAA/APqmv//Z',
);

/// A JPEG of a kind the app's PDF writer cannot read.
final Uint8List oddJpeg = base64Decode(
  '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAMCAgICAgMCAgIDAwMDBAYEBAQEBAgGBgUGCQgK'
  'CgkICQkKDA8MCgsOCwkJDRENDg8QEBEQCgwSExIQEw8QEBD/yQALCAABAAEBAREA/8wABgAQ'
  'EAX/2gAIAQEAAD8A0s8g/9k=',
);

/// Stands in for the other apps on the phone: a test hands a file over
/// with [open].
class FakeIncomingDocuments implements IncomingDocuments {
  final StreamController<PickedDocument> _documents =
      StreamController<PickedDocument>();

  @override
  Stream<PickedDocument> get documents => _documents.stream;

  /// Another app shares [document] to this one.
  void open(PickedDocument document) => _documents.add(document);
}

/// Stands in for the phone's share sheet, and keeps what it was handed.
class FakeScanSharer implements ScanSharer {
  final List<({List<File> files, String name})> shared = [];

  @override
  Future<void> share(List<File> files, {required String name}) async {
    shared.add((files: files, name: name));
  }
}
