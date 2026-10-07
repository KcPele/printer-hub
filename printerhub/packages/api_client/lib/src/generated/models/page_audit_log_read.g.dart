// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'page_audit_log_read.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PageAuditLogRead _$PageAuditLogReadFromJson(Map<String, dynamic> json) =>
    PageAuditLogRead(
      items: (json['items'] as List<dynamic>)
          .map((e) => AuditLogRead.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['next_cursor'] as String?,
    );

Map<String, dynamic> _$PageAuditLogReadToJson(PageAuditLogRead instance) =>
    <String, dynamic>{
      'items': instance.items,
      'next_cursor': instance.nextCursor,
    };
