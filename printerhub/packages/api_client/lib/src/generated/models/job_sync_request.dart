// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'job_sync_item.dart';

part 'job_sync_request.g.dart';

/// Jobs created while offline, with the state changes recorded on the device.
@JsonSerializable()
class JobSyncRequest {
  const JobSyncRequest({required this.items});

  factory JobSyncRequest.fromJson(Map<String, Object?> json) =>
      _$JobSyncRequestFromJson(json);

  final List<JobSyncItem> items;

  Map<String, Object?> toJson() => _$JobSyncRequestToJson(this);
}
