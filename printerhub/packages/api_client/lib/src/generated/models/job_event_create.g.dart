// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_event_create.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

JobEventCreate _$JobEventCreateFromJson(Map<String, dynamic> json) =>
    JobEventCreate(
      status: JobStatus.fromJson(json['status'] as String),
      connectionId: json['connection_id'] as String?,
      detail: json['detail'],
      errorCode: json['error_code'] as String?,
      errorMessage: json['error_message'] as String?,
      occurredAt: json['occurred_at'] == null
          ? null
          : DateTime.parse(json['occurred_at'] as String),
      outputDocumentId: json['output_document_id'] as String?,
      pageCount: (json['page_count'] as num?)?.toInt(),
      printerJobRef: json['printer_job_ref'] as String?,
    );

Map<String, dynamic> _$JobEventCreateToJson(JobEventCreate instance) =>
    <String, dynamic>{
      'connection_id': ?instance.connectionId,
      'detail': ?instance.detail,
      'error_code': ?instance.errorCode,
      'error_message': ?instance.errorMessage,
      'occurred_at': ?instance.occurredAt?.toIso8601String(),
      'output_document_id': ?instance.outputDocumentId,
      'page_count': ?instance.pageCount,
      'printer_job_ref': ?instance.printerJobRef,
      'status': instance.status.toJson(),
    };
