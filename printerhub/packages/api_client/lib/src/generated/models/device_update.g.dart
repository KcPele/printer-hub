// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_update.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceUpdate _$DeviceUpdateFromJson(Map<String, dynamic> json) => DeviceUpdate(
  appVersion: json['app_version'] as String?,
  name: json['name'] as String?,
  osVersion: json['os_version'] as String?,
  pushProvider: json['push_provider'] == null
      ? null
      : PushProviderName.fromJson(json['push_provider'] as String),
  pushToken: json['push_token'] as String?,
);

Map<String, dynamic> _$DeviceUpdateToJson(DeviceUpdate instance) =>
    <String, dynamic>{
      'app_version': instance.appVersion,
      'name': instance.name,
      'os_version': instance.osVersion,
      'push_provider': instance.pushProvider,
      'push_token': instance.pushToken,
    };
