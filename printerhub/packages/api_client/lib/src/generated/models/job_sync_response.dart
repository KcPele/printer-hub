// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'job_sync_result.dart';

part 'job_sync_response.g.dart';

@JsonSerializable()
class JobSyncResponse {
  const JobSyncResponse({required this.results});

  factory JobSyncResponse.fromJson(Map<String, Object?> json) =>
      _$JobSyncResponseFromJson(json);

  final List<JobSyncResult> results;

  Map<String, Object?> toJson() => _$JobSyncResponseToJson(this);
}
