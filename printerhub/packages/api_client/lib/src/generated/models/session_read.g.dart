// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_read.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionRead _$SessionReadFromJson(Map<String, dynamic> json) => SessionRead(
  createdAt: DateTime.parse(json['created_at'] as String),
  deviceId: json['device_id'] as String?,
  expiresAt: DateTime.parse(json['expires_at'] as String),
  id: json['id'] as String,
  ip: json['ip'] as String?,
  lastUsedAt: DateTime.parse(json['last_used_at'] as String),
  userAgent: json['user_agent'] as String?,
  isCurrent: json['is_current'] as bool? ?? false,
);

Map<String, dynamic> _$SessionReadToJson(SessionRead instance) =>
    <String, dynamic>{
      'created_at': instance.createdAt.toIso8601String(),
      'device_id': ?instance.deviceId,
      'expires_at': instance.expiresAt.toIso8601String(),
      'id': instance.id,
      'ip': ?instance.ip,
      'is_current': instance.isCurrent,
      'last_used_at': instance.lastUsedAt.toIso8601String(),
      'user_agent': ?instance.userAgent,
    };
