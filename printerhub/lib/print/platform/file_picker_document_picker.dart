// Opens the phone's file browser through a plugin, which only exists on a
// device.
// coverage:ignore-file

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:printerhub/print/documents.dart';

/// Chooses a PDF or a picture with the phone's own file browser.
class FilePickerDocumentPicker implements DocumentPicker {
  const new();

  @override
  Future<PickedDocument?> pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    final path = file?.path;
    if (file == null || path == null) return null;
    return PickedDocument(
      name: file.name,
      path: path,
      length: file.lengthSync() ?? await file.length() ?? 0,
      open: File(path).openRead,
    );
  }
}
