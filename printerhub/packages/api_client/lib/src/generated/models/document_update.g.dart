// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_update.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DocumentUpdate _$DocumentUpdateFromJson(Map<String, dynamic> json) =>
    DocumentUpdate(
      fileName: json['file_name'] as String?,
      ocrText: json['ocr_text'] as String?,
      pageCount: (json['page_count'] as num?)?.toInt(),
      shared: json['shared'] as bool?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );

Map<String, dynamic> _$DocumentUpdateToJson(DocumentUpdate instance) =>
    <String, dynamic>{
      'file_name': ?instance.fileName,
      'ocr_text': ?instance.ocrText,
      'page_count': ?instance.pageCount,
      'shared': ?instance.shared,
      'tags': ?instance.tags,
    };
