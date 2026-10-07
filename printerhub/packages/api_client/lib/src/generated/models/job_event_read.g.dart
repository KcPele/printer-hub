// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_event_read.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

JobEventRead _$JobEventReadFromJson(Map<String, dynamic> json) => JobEventRead(
  connectionId: json['connection_id'] as String?,
  connectionType: json['connection_type'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
  detail: json['detail'],
  errorCode: json['error_code'] as String?,
  errorMessage: json['error_message'] as String?,
  id: json['id'] as String,
  occurredAt: DateTime.parse(json['occurred_at'] as String),
  reportedByUserId: json['reported_by_user_id'] as String?,
  status: JobStatus.fromJson(json['status'] as String),
);

Map<String, dynamic> _$JobEventReadToJson(JobEventRead instance) =>
    <String, dynamic>{
      'connection_id': ?instance.connectionId,
      'connection_type': ?instance.connectionType,
      'created_at': instance.createdAt.toIso8601String(),
      'detail': ?instance.detail,
      'error_code': ?instance.errorCode,
      'error_message': ?instance.errorMessage,
      'id': instance.id,
      'occurred_at': instance.occurredAt.toIso8601String(),
      'reported_by_user_id': ?instance.reportedByUserId,
      'status': instance.status.toJson(),
    };
