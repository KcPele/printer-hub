// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'document_source.dart';
import 'storage_mode.dart';
import 'upload_status.dart';

part 'document_read.g.dart';

@JsonSerializable()
class DocumentRead {
  const DocumentRead({
    required this.checksumSha256,
    required this.createdAt,
    required this.fileName,
    required this.hasOcrText,
    required this.id,
    required this.mimeType,
    required this.organizationId,
    required this.ownerId,
    required this.pageCount,
    required this.retentionExpiresAt,
    required this.shared,
    required this.sizeBytes,
    required this.source,
    required this.sourcePrinterId,
    required this.storageMode,
    required this.tags,
    required this.updatedAt,
    required this.uploadStatus,
  });

  factory DocumentRead.fromJson(Map<String, Object?> json) =>
      _$DocumentReadFromJson(json);

  @JsonKey(name: 'checksum_sha256')
  final String? checksumSha256;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'file_name')
  final String fileName;
  @JsonKey(name: 'has_ocr_text')
  final bool hasOcrText;
  final String id;
  @JsonKey(name: 'mime_type')
  final String mimeType;
  @JsonKey(name: 'organization_id')
  final String organizationId;
  @JsonKey(name: 'owner_id')
  final String? ownerId;
  @JsonKey(name: 'page_count')
  final int? pageCount;
  @JsonKey(name: 'retention_expires_at')
  final DateTime? retentionExpiresAt;
  final bool shared;
  @JsonKey(name: 'size_bytes')
  final int sizeBytes;
  final DocumentSource source;
  @JsonKey(name: 'source_printer_id')
  final String? sourcePrinterId;
  @JsonKey(name: 'storage_mode')
  final StorageMode storageMode;
  final List<String> tags;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  @JsonKey(name: 'upload_status')
  final UploadStatus uploadStatus;

  Map<String, Object?> toJson() => _$DocumentReadToJson(this);
}
