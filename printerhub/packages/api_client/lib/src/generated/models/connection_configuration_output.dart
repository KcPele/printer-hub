// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'connection_configuration_output.g.dart';

/// Where and how to reach the printer. Never holds secrets.
@JsonSerializable()
class ConnectionConfigurationOutput {
  const ConnectionConfigurationOutput({
    required this.host,
    required this.options,
    required this.path,
    required this.port,
    required this.serviceName,
    required this.ssid,
    required this.tls,
  });

  factory ConnectionConfigurationOutput.fromJson(Map<String, Object?> json) =>
      _$ConnectionConfigurationOutputFromJson(json);

  final String? host;
  final Map<String, String> options;
  final String? path;
  final int? port;
  @JsonKey(name: 'service_name')
  final String? serviceName;
  final String? ssid;
  final bool? tls;

  Map<String, Object?> toJson() => _$ConnectionConfigurationOutputToJson(this);
}
