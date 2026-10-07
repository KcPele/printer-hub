// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_create.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$JobCreateToJson(JobCreate instance) =>
    <String, dynamic>{};

JobCreateCopyJobCreate _$JobCreateCopyJobCreateFromJson(
  Map<String, dynamic> json,
) => JobCreateCopyJobCreate(
  connectionId: json['connection_id'] as String?,
  documentId: json['document_id'] as String?,
  executionMode: ExecutionMode.fromJson(json['execution_mode'] as String),
  id: json['id'] as String?,
  pageCount: (json['page_count'] as num?)?.toInt(),
  printerId: json['printer_id'] as String,
  settings: json['settings'] == null
      ? null
      : CopySettingsInput.fromJson(json['settings'] as Map<String, dynamic>),
  submittedAt: json['submitted_at'] == null
      ? null
      : DateTime.parse(json['submitted_at'] as String),
  title: json['title'] as String?,
  type: json['type'] as String,
);

Map<String, dynamic> _$JobCreateCopyJobCreateToJson(
  JobCreateCopyJobCreate instance,
) => <String, dynamic>{
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

JobCreatePrintJobCreate _$JobCreatePrintJobCreateFromJson(
  Map<String, dynamic> json,
) => JobCreatePrintJobCreate(
  connectionId: json['connection_id'] as String?,
  documentId: json['document_id'] as String?,
  executionMode: ExecutionMode.fromJson(json['execution_mode'] as String),
  id: json['id'] as String?,
  pageCount: (json['page_count'] as num?)?.toInt(),
  printerId: json['printer_id'] as String,
  settings: json['settings'] == null
      ? null
      : PrintSettingsInput.fromJson(json['settings'] as Map<String, dynamic>),
  submittedAt: json['submitted_at'] == null
      ? null
      : DateTime.parse(json['submitted_at'] as String),
  title: json['title'] as String?,
  type: json['type'] as String,
);

Map<String, dynamic> _$JobCreatePrintJobCreateToJson(
  JobCreatePrintJobCreate instance,
) => <String, dynamic>{
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

JobCreateScanJobCreate _$JobCreateScanJobCreateFromJson(
  Map<String, dynamic> json,
) => JobCreateScanJobCreate(
  connectionId: json['connection_id'] as String?,
  documentId: json['document_id'] as String?,
  executionMode: ExecutionMode.fromJson(json['execution_mode'] as String),
  id: json['id'] as String?,
  pageCount: (json['page_count'] as num?)?.toInt(),
  printerId: json['printer_id'] as String,
  settings: json['settings'] == null
      ? null
      : ScanSettingsInput.fromJson(json['settings'] as Map<String, dynamic>),
  submittedAt: json['submitted_at'] == null
      ? null
      : DateTime.parse(json['submitted_at'] as String),
  title: json['title'] as String?,
  type: json['type'] as String,
);

Map<String, dynamic> _$JobCreateScanJobCreateToJson(
  JobCreateScanJobCreate instance,
) => <String, dynamic>{
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
