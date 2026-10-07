// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'session_read.g.dart';

@JsonSerializable()
class SessionRead {
  const SessionRead({
    required this.createdAt,
    required this.deviceId,
    required this.expiresAt,
    required this.id,
    required this.ip,
    required this.lastUsedAt,
    required this.userAgent,
    this.isCurrent = false,
  });

  factory SessionRead.fromJson(Map<String, Object?> json) =>
      _$SessionReadFromJson(json);

  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'device_id')
  final String? deviceId;
  @JsonKey(name: 'expires_at')
  final DateTime expiresAt;
  final String id;
  final String? ip;
  @JsonKey(name: 'is_current')
  final bool isCurrent;
  @JsonKey(name: 'last_used_at')
  final DateTime lastUsedAt;
  @JsonKey(name: 'user_agent')
  final String? userAgent;

  Map<String, Object?> toJson() => _$SessionReadToJson(this);
}
