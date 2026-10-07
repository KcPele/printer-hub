// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'copy_job_create.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CopyJobCreate _$CopyJobCreateFromJson(Map<String, dynamic> json) =>
    CopyJobCreate(
      printerId: json['printer_id'] as String,
      type: json['type'] as String,
      executionMode: json['execution_mode'] == null
          ? ExecutionMode.local
          : ExecutionMode.fromJson(json['execution_mode'] as String),
      connectionId: json['connection_id'] as String?,
      documentId: json['document_id'] as String?,
      id: json['id'] as String?,
      pageCount: (json['page_count'] as num?)?.toInt(),
      settings: json['settings'] == null
          ? null
          : CopySettingsInput.fromJson(
              json['settings'] as Map<String, dynamic>,
            ),
      submittedAt: json['submitted_at'] == null
          ? null
          : DateTime.parse(json['submitted_at'] as String),
      title: json['title'] as String?,
    );

Map<String, dynamic> _$CopyJobCreateToJson(CopyJobCreate instance) =>
    <String, dynamic>{
      'connection_id': instance.connectionId,
      'document_id': instance.documentId,
      'execution_mode': instance.executionMode,
      'id': instance.id,
      'page_count': instance.pageCount,
      'printer_id': instance.printerId,
      'settings': instance.settings,
      'submitted_at': instance.submittedAt?.toIso8601String(),
      'title': instance.title,
      'type': instance.type,
    };
