// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_read.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationRead _$NotificationReadFromJson(Map<String, dynamic> json) =>
    NotificationRead(
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      data: Map<String, String>.from(json['data'] as Map),
      id: json['id'] as String,
      organizationId: json['organization_id'] as String?,
      readAt: json['read_at'] == null
          ? null
          : DateTime.parse(json['read_at'] as String),
      title: json['title'] as String,
      type: json['type'] as String,
    );

Map<String, dynamic> _$NotificationReadToJson(NotificationRead instance) =>
    <String, dynamic>{
      'body': instance.body,
      'created_at': instance.createdAt.toIso8601String(),
      'data': instance.data,
      'id': instance.id,
      'organization_id': ?instance.organizationId,
      'read_at': ?instance.readAt?.toIso8601String(),
      'title': instance.title,
      'type': instance.type,
    };
