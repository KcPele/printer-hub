// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'notification_read.g.dart';

@JsonSerializable()
class NotificationRead {
  const NotificationRead({
    required this.body,
    required this.createdAt,
    required this.data,
    required this.id,
    required this.organizationId,
    required this.readAt,
    required this.title,
    required this.type,
  });

  factory NotificationRead.fromJson(Map<String, Object?> json) =>
      _$NotificationReadFromJson(json);

  final String body;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  final Map<String, String> data;
  final String id;
  @JsonKey(name: 'organization_id')
  final String? organizationId;
  @JsonKey(name: 'read_at')
  final DateTime? readAt;
  final String title;
  final String type;

  Map<String, Object?> toJson() => _$NotificationReadToJson(this);
}
