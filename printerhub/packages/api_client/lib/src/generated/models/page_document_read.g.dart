// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'page_document_read.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PageDocumentRead _$PageDocumentReadFromJson(Map<String, dynamic> json) =>
    PageDocumentRead(
      items: (json['items'] as List<dynamic>)
          .map((e) => DocumentRead.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['next_cursor'] as String?,
    );

Map<String, dynamic> _$PageDocumentReadToJson(PageDocumentRead instance) =>
    <String, dynamic>{
      'items': instance.items.map((e) => e.toJson()).toList(),
      'next_cursor': ?instance.nextCursor,
    };
