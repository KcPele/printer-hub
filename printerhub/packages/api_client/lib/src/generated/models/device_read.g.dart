// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_read.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceRead _$DeviceReadFromJson(Map<String, dynamic> json) => DeviceRead(
  appVersion: json['app_version'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
  id: json['id'] as String,
  installationId: json['installation_id'] as String,
  lastSeenAt: DateTime.parse(json['last_seen_at'] as String),
  model: json['model'] as String?,
  name: json['name'] as String?,
  osVersion: json['os_version'] as String?,
  platform: DevicePlatform.fromJson(json['platform'] as String),
  pushEnabled: json['push_enabled'] as bool,
  pushProvider: json['push_provider'] == null
      ? null
      : PushProviderName.fromJson(json['push_provider'] as String),
);

Map<String, dynamic> _$DeviceReadToJson(DeviceRead instance) =>
    <String, dynamic>{
      'app_version': ?instance.appVersion,
      'created_at': instance.createdAt.toIso8601String(),
      'id': instance.id,
      'installation_id': instance.installationId,
      'last_seen_at': instance.lastSeenAt.toIso8601String(),
      'model': ?instance.model,
      'name': ?instance.name,
      'os_version': ?instance.osVersion,
      'platform': instance.platform.toJson(),
      'push_enabled': instance.pushEnabled,
      'push_provider': ?instance.pushProvider?.toJson(),
    };
