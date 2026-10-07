// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'job_create.dart';
import 'job_event_create.dart';

part 'job_sync_item.g.dart';

@JsonSerializable()
class JobSyncItem {
  const JobSyncItem({
    required this.idempotencyKey,
    required this.job,
    this.events,
  });

  factory JobSyncItem.fromJson(Map<String, Object?> json) =>
      _$JobSyncItemFromJson(json);

  final List<JobEventCreate>? events;
  @JsonKey(name: 'idempotency_key')
  final String idempotencyKey;
  final JobCreate job;

  Map<String, Object?> toJson() => _$JobSyncItemToJson(this);
}
