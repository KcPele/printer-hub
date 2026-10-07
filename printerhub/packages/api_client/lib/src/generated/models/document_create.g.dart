// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_create.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DocumentCreate _$DocumentCreateFromJson(Map<String, dynamic> json) =>
    DocumentCreate(
      fileName: json['file_name'] as String,
      mimeType: json['mime_type'] as String,
      sizeBytes: (json['size_bytes'] as num).toInt(),
      source: json['source'] == null
          ? DocumentSource.upload
          : DocumentSource.fromJson(json['source'] as String),
      storageMode: json['storage_mode'] == null
          ? StorageMode.local
          : StorageMode.fromJson(json['storage_mode'] as String),
      checksumSha256: json['checksum_sha256'] as String?,
      id: json['id'] as String?,
      ocrText: json['ocr_text'] as String?,
      pageCount: (json['page_count'] as num?)?.toInt(),
      sourcePrinterId: json['source_printer_id'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );

Map<String, dynamic> _$DocumentCreateToJson(DocumentCreate instance) =>
    <String, dynamic>{
      'checksum_sha256': ?instance.checksumSha256,
      'file_name': instance.fileName,
      'id': ?instance.id,
      'mime_type': instance.mimeType,
      'ocr_text': ?instance.ocrText,
      'page_count': ?instance.pageCount,
      'size_bytes': instance.sizeBytes,
      'source': instance.source.toJson(),
      'source_printer_id': ?instance.sourcePrinterId,
      'storage_mode': instance.storageMode.toJson(),
      'tags': ?instance.tags,
    };
