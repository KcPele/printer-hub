// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'connection_configuration_input.g.dart';

/// Where and how to reach the printer. Never holds secrets.
@JsonSerializable()
class ConnectionConfigurationInput {
  const ConnectionConfigurationInput({
    this.host,
    this.options,
    this.path,
    this.port,
    this.serviceName,
    this.ssid,
    this.tls,
  });

  factory ConnectionConfigurationInput.fromJson(Map<String, Object?> json) =>
      _$ConnectionConfigurationInputFromJson(json);

  final String? host;
  final Map<String, String>? options;
  final String? path;
  final int? port;
  @JsonKey(name: 'service_name')
  final String? serviceName;
  final String? ssid;
  final bool? tls;

  Map<String, Object?> toJson() => _$ConnectionConfigurationInputToJson(this);
}
