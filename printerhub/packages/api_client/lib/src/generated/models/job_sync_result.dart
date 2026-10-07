// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'job_read.dart';
import 'job_sync_error.dart';
import 'job_sync_result_outcome.dart';

part 'job_sync_result.g.dart';

@JsonSerializable()
class JobSyncResult {
  const JobSyncResult({
    required this.error,
    required this.idempotencyKey,
    required this.job,
    required this.outcome,
  });

  factory JobSyncResult.fromJson(Map<String, Object?> json) =>
      _$JobSyncResultFromJson(json);

  final JobSyncError? error;
  @JsonKey(name: 'idempotency_key')
  final String idempotencyKey;
  final JobRead? job;
  final JobSyncResultOutcome outcome;

  Map<String, Object?> toJson() => _$JobSyncResultToJson(this);
}
