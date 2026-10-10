// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_created.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DocumentCreated _$DocumentCreatedFromJson(Map<String, dynamic> json) =>
    DocumentCreated(
      checksumSha256: json['checksum_sha256'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      fileName: json['file_name'] as String,
      hasOcrText: json['has_ocr_text'] as bool,
      id: json['id'] as String,
      mimeType: json['mime_type'] as String,
      organizationId: json['organization_id'] as String,
      ownerId: json['owner_id'] as String?,
      pageCount: (json['page_count'] as num?)?.toInt(),
      retentionExpiresAt: json['retention_expires_at'] == null
          ? null
          : DateTime.parse(json['retention_expires_at'] as String),
      shared: json['shared'] as bool,
      sizeBytes: (json['size_bytes'] as num).toInt(),
      source: DocumentSource.fromJson(json['source'] as String),
      sourcePrinterId: json['source_printer_id'] as String?,
      storageMode: StorageMode.fromJson(json['storage_mode'] as String),
      tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      upload: json['upload'] == null
          ? null
          : UploadInstructions.fromJson(json['upload'] as Map<String, dynamic>),
      uploadStatus: UploadStatus.fromJson(json['upload_status'] as String),
    );

Map<String, dynamic> _$DocumentCreatedToJson(DocumentCreated instance) =>
    <String, dynamic>{
      'checksum_sha256': ?instance.checksumSha256,
      'created_at': instance.createdAt.toIso8601String(),
      'file_name': instance.fileName,
      'has_ocr_text': instance.hasOcrText,
      'id': instance.id,
      'mime_type': instance.mimeType,
      'organization_id': instance.organizationId,
      'owner_id': ?instance.ownerId,
      'page_count': ?instance.pageCount,
      'retention_expires_at': ?instance.retentionExpiresAt?.toIso8601String(),
      'shared': instance.shared,
      'size_bytes': instance.sizeBytes,
      'source': instance.source.toJson(),
      'source_printer_id': ?instance.sourcePrinterId,
      'storage_mode': instance.storageMode.toJson(),
      'tags': instance.tags,
      'updated_at': instance.updatedAt.toIso8601String(),
      'upload': ?instance.upload?.toJson(),
      'upload_status': instance.uploadStatus.toJson(),
    };
