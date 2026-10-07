// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'job_status.dart';

part 'job_event_read.g.dart';

@JsonSerializable()
class JobEventRead {
  const JobEventRead({
    required this.connectionId,
    required this.connectionType,
    required this.createdAt,
    required this.detail,
    required this.errorCode,
    required this.errorMessage,
    required this.id,
    required this.occurredAt,
    required this.reportedByUserId,
    required this.status,
  });

  factory JobEventRead.fromJson(Map<String, Object?> json) =>
      _$JobEventReadFromJson(json);

  @JsonKey(name: 'connection_id')
  final String? connectionId;
  @JsonKey(name: 'connection_type')
  final String? connectionType;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  final dynamic detail;
  @JsonKey(name: 'error_code')
  final String? errorCode;
  @JsonKey(name: 'error_message')
  final String? errorMessage;
  final String id;
  @JsonKey(name: 'occurred_at')
  final DateTime occurredAt;
  @JsonKey(name: 'reported_by_user_id')
  final String? reportedByUserId;
  final JobStatus status;

  Map<String, Object?> toJson() => _$JobEventReadToJson(this);
}
