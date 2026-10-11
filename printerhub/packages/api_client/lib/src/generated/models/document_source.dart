// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum DocumentSource {
  @JsonValue('upload')
  upload('upload'),
  @JsonValue('printer_scan')
  printerScan('printer_scan'),
  @JsonValue('camera_scan')
  cameraScan('camera_scan'),
  @JsonValue('joined_files')
  joinedFiles('joined_files'),
  @JsonValue('pdf_pictures')
  pdfPictures('pdf_pictures'),
  @JsonValue('long_picture')
  longPicture('long_picture'),
  @JsonValue('photo_sheet')
  photoSheet('photo_sheet'),
  @JsonValue('pages_per_sheet')
  pagesPerSheet('pages_per_sheet'),
  @JsonValue('code_sheet')
  codeSheet('code_sheet'),
  @JsonValue('note')
  note('note'),
  @JsonValue('printable')
  printable('printable'),
  @JsonValue('edited_picture')
  editedPicture('edited_picture'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const DocumentSource(this.json);

  factory DocumentSource.fromJson(String json) =>
      values.firstWhere((e) => e.json == json, orElse: () => $unknown);

  final String? json;
  String toJson() {
    final value = json;
    if (value == null) {
      throw StateError(
        'Cannot convert enum value with null JSON representation to String. '
        'This usually happens for \$unknown or @JsonValue(null) entries.',
      );
    }
    return value as String;
  }

  @override
  String toString() => json?.toString() ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<DocumentSource> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
