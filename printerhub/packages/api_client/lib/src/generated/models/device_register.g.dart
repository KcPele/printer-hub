// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_register.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceRegister _$DeviceRegisterFromJson(Map<String, dynamic> json) =>
    DeviceRegister(
      installationId: json['installation_id'] as String,
      platform: DevicePlatform.fromJson(json['platform'] as String),
      appVersion: json['app_version'] as String?,
      model: json['model'] as String?,
      name: json['name'] as String?,
      osVersion: json['os_version'] as String?,
      pushProvider: json['push_provider'] == null
          ? null
          : PushProviderName.fromJson(json['push_provider'] as String),
      pushToken: json['push_token'] as String?,
    );

Map<String, dynamic> _$DeviceRegisterToJson(DeviceRegister instance) =>
    <String, dynamic>{
      'app_version': instance.appVersion,
      'installation_id': instance.installationId,
      'model': instance.model,
      'name': instance.name,
      'os_version': instance.osVersion,
      'platform': instance.platform,
      'push_provider': instance.pushProvider,
      'push_token': instance.pushToken,
    };
