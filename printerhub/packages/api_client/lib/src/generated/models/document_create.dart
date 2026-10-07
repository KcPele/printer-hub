// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'document_source.dart';
import 'storage_mode.dart';

part 'document_create.g.dart';

@JsonSerializable()
class DocumentCreate {
  const DocumentCreate({
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    this.source = DocumentSource.upload,
    this.storageMode = StorageMode.local,
    this.checksumSha256,
    this.id,
    this.ocrText,
    this.pageCount,
    this.sourcePrinterId,
    this.tags,
  });

  factory DocumentCreate.fromJson(Map<String, Object?> json) =>
      _$DocumentCreateFromJson(json);

  @JsonKey(name: 'checksum_sha256')
  final String? checksumSha256;
  @JsonKey(name: 'file_name')
  final String fileName;

  /// Client-generated ID, for documents created offline
  final String? id;
  @JsonKey(name: 'mime_type')
  final String mimeType;
  @JsonKey(name: 'ocr_text')
  final String? ocrText;
  @JsonKey(name: 'page_count')
  final int? pageCount;
  @JsonKey(name: 'size_bytes')
  final int sizeBytes;
  final DocumentSource source;
  @JsonKey(name: 'source_printer_id')
  final String? sourcePrinterId;
  @JsonKey(name: 'storage_mode')
  final StorageMode storageMode;
  final List<String>? tags;

  Map<String, Object?> toJson() => _$DocumentCreateToJson(this);
}
