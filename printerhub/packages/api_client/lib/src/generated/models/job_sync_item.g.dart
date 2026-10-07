// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_sync_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

JobSyncItem _$JobSyncItemFromJson(Map<String, dynamic> json) => JobSyncItem(
  idempotencyKey: json['idempotency_key'] as String,
  job: JobCreate.fromJson(json['job'] as Map<String, dynamic>),
  events: (json['events'] as List<dynamic>?)
      ?.map((e) => JobEventCreate.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$JobSyncItemToJson(JobSyncItem instance) =>
    <String, dynamic>{
      'events': ?instance.events?.map((e) => e.toJson()).toList(),
      'idempotency_key': instance.idempotencyKey,
      'job': instance.job.toJson(),
    };
