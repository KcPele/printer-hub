// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_configuration_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConnectionConfigurationInput _$ConnectionConfigurationInputFromJson(
  Map<String, dynamic> json,
) => ConnectionConfigurationInput(
  host: json['host'] as String?,
  options: (json['options'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  path: json['path'] as String?,
  port: (json['port'] as num?)?.toInt(),
  serviceName: json['service_name'] as String?,
  ssid: json['ssid'] as String?,
  tls: json['tls'] as bool?,
);

Map<String, dynamic> _$ConnectionConfigurationInputToJson(
  ConnectionConfigurationInput instance,
) => <String, dynamic>{
  'host': ?instance.host,
  'options': ?instance.options,
  'path': ?instance.path,
  'port': ?instance.port,
  'service_name': ?instance.serviceName,
  'ssid': ?instance.ssid,
  'tls': ?instance.tls,
};
