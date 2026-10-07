// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_sync_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

JobSyncRequest _$JobSyncRequestFromJson(Map<String, dynamic> json) =>
    JobSyncRequest(
      items: (json['items'] as List<dynamic>)
          .map((e) => JobSyncItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$JobSyncRequestToJson(JobSyncRequest instance) =>
    <String, dynamic>{'items': instance.items.map((e) => e.toJson()).toList()};
