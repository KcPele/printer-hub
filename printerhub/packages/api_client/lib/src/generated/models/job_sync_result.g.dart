// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_sync_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

JobSyncResult _$JobSyncResultFromJson(Map<String, dynamic> json) =>
    JobSyncResult(
      error: json['error'] == null
          ? null
          : JobSyncError.fromJson(json['error'] as Map<String, dynamic>),
      idempotencyKey: json['idempotency_key'] as String,
      job: json['job'] == null
          ? null
          : JobRead.fromJson(json['job'] as Map<String, dynamic>),
      outcome: JobSyncResultOutcome.fromJson(json['outcome'] as String),
    );

Map<String, dynamic> _$JobSyncResultToJson(JobSyncResult instance) =>
    <String, dynamic>{
      'error': instance.error,
      'idempotency_key': instance.idempotencyKey,
      'job': instance.job,
      'outcome': instance.outcome,
    };
