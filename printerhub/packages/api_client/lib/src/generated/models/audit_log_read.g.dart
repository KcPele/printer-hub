// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audit_log_read.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuditLogRead _$AuditLogReadFromJson(Map<String, dynamic> json) => AuditLogRead(
  action: json['action'] as String,
  actorUserId: json['actor_user_id'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
  detail: json['detail'],
  id: json['id'] as String,
  ip: json['ip'] as String?,
  outcome: AuditOutcome.fromJson(json['outcome'] as String),
  targetId: json['target_id'] as String?,
  targetType: json['target_type'] as String,
);

Map<String, dynamic> _$AuditLogReadToJson(AuditLogRead instance) =>
    <String, dynamic>{
      'action': instance.action,
      'actor_user_id': instance.actorUserId,
      'created_at': instance.createdAt.toIso8601String(),
      'detail': instance.detail,
      'id': instance.id,
      'ip': instance.ip,
      'outcome': instance.outcome,
      'target_id': instance.targetId,
      'target_type': instance.targetType,
    };
