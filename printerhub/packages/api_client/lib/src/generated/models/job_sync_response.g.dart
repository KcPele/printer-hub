// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_sync_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

JobSyncResponse _$JobSyncResponseFromJson(Map<String, dynamic> json) =>
    JobSyncResponse(
      results: (json['results'] as List<dynamic>)
          .map((e) => JobSyncResult.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$JobSyncResponseToJson(JobSyncResponse instance) =>
    <String, dynamic>{'results': instance.results};
