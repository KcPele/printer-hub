// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'print_job_read.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrintJobRead _$PrintJobReadFromJson(Map<String, dynamic> json) => PrintJobRead(
  completedAt: json['completed_at'] == null
      ? null
      : DateTime.parse(json['completed_at'] as String),
  connectionId: json['connection_id'] as String?,
  connectionType: json['connection_type'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
  deviceId: json['device_id'] as String?,
  documentId: json['document_id'] as String?,
  errorCode: json['error_code'] as String?,
  errorMessage: json['error_message'] as String?,
  executionMode: ExecutionMode.fromJson(json['execution_mode'] as String),
  fallbackOccurred: json['fallback_occurred'] as bool,
  id: json['id'] as String,
  organizationId: json['organization_id'] as String,
  outputDocumentId: json['output_document_id'] as String?,
  pageCount: (json['page_count'] as num?)?.toInt(),
  printerId: json['printer_id'] as String,
  printerJobRef: json['printer_job_ref'] as String?,
  retryOfJobId: json['retry_of_job_id'] as String?,
  settings: PrintSettingsOutput.fromJson(
    json['settings'] as Map<String, dynamic>,
  ),
  startedAt: json['started_at'] == null
      ? null
      : DateTime.parse(json['started_at'] as String),
  status: JobStatus.fromJson(json['status'] as String),
  submittedAt: DateTime.parse(json['submitted_at'] as String),
  title: json['title'] as String?,
  type: json['type'] as String,
  updatedAt: DateTime.parse(json['updated_at'] as String),
  userId: json['user_id'] as String?,
);

Map<String, dynamic> _$PrintJobReadToJson(PrintJobRead instance) =>
    <String, dynamic>{
      'completed_at': instance.completedAt?.toIso8601String(),
      'connection_id': instance.connectionId,
      'connection_type': instance.connectionType,
      'created_at': instance.createdAt.toIso8601String(),
      'device_id': instance.deviceId,
      'document_id': instance.documentId,
      'error_code': instance.errorCode,
      'error_message': instance.errorMessage,
      'execution_mode': instance.executionMode,
      'fallback_occurred': instance.fallbackOccurred,
      'id': instance.id,
      'organization_id': instance.organizationId,
      'output_document_id': instance.outputDocumentId,
      'page_count': instance.pageCount,
      'printer_id': instance.printerId,
      'printer_job_ref': instance.printerJobRef,
      'retry_of_job_id': instance.retryOfJobId,
      'settings': instance.settings,
      'started_at': instance.startedAt?.toIso8601String(),
      'status': instance.status,
      'submitted_at': instance.submittedAt.toIso8601String(),
      'title': instance.title,
      'type': instance.type,
      'updated_at': instance.updatedAt.toIso8601String(),
      'user_id': instance.userId,
    };
