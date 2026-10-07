// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'audit_outcome.dart';

part 'audit_log_read.g.dart';

@JsonSerializable()
class AuditLogRead {
  const AuditLogRead({
    required this.action,
    required this.actorUserId,
    required this.createdAt,
    required this.detail,
    required this.id,
    required this.ip,
    required this.outcome,
    required this.targetId,
    required this.targetType,
  });

  factory AuditLogRead.fromJson(Map<String, Object?> json) =>
      _$AuditLogReadFromJson(json);

  final String action;
  @JsonKey(name: 'actor_user_id')
  final String? actorUserId;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  final dynamic detail;
  final String id;
  final String? ip;
  final AuditOutcome outcome;
  @JsonKey(name: 'target_id')
  final String? targetId;
  @JsonKey(name: 'target_type')
  final String targetType;

  Map<String, Object?> toJson() => _$AuditLogReadToJson(this);
}
