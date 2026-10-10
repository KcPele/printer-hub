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
  Future<PickedDocument?> pick() => _one(const ['pdf', 'jpg', 'jpeg', 'png']);

  @override
  Future<PickedDocument?> pickPdf() => _one(const ['pdf']);

  @override
  Future<List<PickedDocument>> pickPictures() =>
      _several(const ['jpg', 'jpeg', 'png']);

  @override
  Future<List<PickedDocument>> pickFiles() =>
      _several(const ['pdf', 'jpg', 'jpeg', 'png']);

  Future<List<PickedDocument>> _several(List<String> endings) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: endings,
    );
    return [for (final file in files) ?await _picked(file)];
  }

  Future<PickedDocument?> _one(List<String> endings) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: endings,
    );
    return file == null ? null : await _picked(file);
  }

  static Future<PickedDocument?> _picked(PlatformFile file) async {
    final path = file.path;
    if (path == null) return null;
    return PickedDocument(
      name: file.name,
      path: path,
      length: file.lengthSync() ?? await file.length() ?? 0,
      open: File(path).openRead,
    );
  }
}
