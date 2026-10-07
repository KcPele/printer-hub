// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'device_platform.dart';
import 'push_provider_name.dart';

part 'device_register.g.dart';

@JsonSerializable()
class DeviceRegister {
  const DeviceRegister({
    required this.installationId,
    required this.platform,
    this.appVersion,
    this.model,
    this.name,
    this.osVersion,
    this.pushProvider,
    this.pushToken,
  });

  factory DeviceRegister.fromJson(Map<String, Object?> json) =>
      _$DeviceRegisterFromJson(json);

  @JsonKey(name: 'app_version')
  final String? appVersion;
  @JsonKey(name: 'installation_id')
  final String installationId;
  final String? model;
  final String? name;
  @JsonKey(name: 'os_version')
  final String? osVersion;
  final DevicePlatform platform;
  @JsonKey(name: 'push_provider')
  final PushProviderName? pushProvider;
  @JsonKey(name: 'push_token')
  final String? pushToken;

  Map<String, Object?> toJson() => _$DeviceRegisterToJson(this);
}
