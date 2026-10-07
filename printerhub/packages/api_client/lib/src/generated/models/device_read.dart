// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'device_platform.dart';
import 'push_provider_name.dart';

part 'device_read.g.dart';

@JsonSerializable()
class DeviceRead {
  const DeviceRead({
    required this.appVersion,
    required this.createdAt,
    required this.id,
    required this.installationId,
    required this.lastSeenAt,
    required this.model,
    required this.name,
    required this.osVersion,
    required this.platform,
    required this.pushEnabled,
    required this.pushProvider,
  });

  factory DeviceRead.fromJson(Map<String, Object?> json) =>
      _$DeviceReadFromJson(json);

  @JsonKey(name: 'app_version')
  final String? appVersion;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  final String id;
  @JsonKey(name: 'installation_id')
  final String installationId;
  @JsonKey(name: 'last_seen_at')
  final DateTime lastSeenAt;
  final String? model;
  final String? name;
  @JsonKey(name: 'os_version')
  final String? osVersion;
  final DevicePlatform platform;
  @JsonKey(name: 'push_enabled')
  final bool pushEnabled;
  @JsonKey(name: 'push_provider')
  final PushProviderName? pushProvider;

  Map<String, Object?> toJson() => _$DeviceReadToJson(this);
}
