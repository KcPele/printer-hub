// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'push_provider_name.dart';

part 'device_update.g.dart';

/// Fields left out are unchanged. Send both push fields as null to stop push.
@JsonSerializable()
class DeviceUpdate {
  const DeviceUpdate({
    this.appVersion,
    this.name,
    this.osVersion,
    this.pushProvider,
    this.pushToken,
  });

  factory DeviceUpdate.fromJson(Map<String, Object?> json) =>
      _$DeviceUpdateFromJson(json);

  @JsonKey(name: 'app_version')
  final String? appVersion;
  final String? name;
  @JsonKey(name: 'os_version')
  final String? osVersion;
  @JsonKey(name: 'push_provider')
  final PushProviderName? pushProvider;
  @JsonKey(name: 'push_token')
  final String? pushToken;

  Map<String, Object?> toJson() => _$DeviceUpdateToJson(this);
}
