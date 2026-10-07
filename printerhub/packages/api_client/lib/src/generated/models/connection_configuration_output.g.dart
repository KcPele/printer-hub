// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_configuration_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConnectionConfigurationOutput _$ConnectionConfigurationOutputFromJson(
  Map<String, dynamic> json,
) => ConnectionConfigurationOutput(
  host: json['host'] as String?,
  options: Map<String, String>.from(json['options'] as Map),
  path: json['path'] as String?,
  port: (json['port'] as num?)?.toInt(),
  serviceName: json['service_name'] as String?,
  ssid: json['ssid'] as String?,
  tls: json['tls'] as bool?,
);

Map<String, dynamic> _$ConnectionConfigurationOutputToJson(
  ConnectionConfigurationOutput instance,
) => <String, dynamic>{
  'host': ?instance.host,
  'options': instance.options,
  'path': ?instance.path,
  'port': ?instance.port,
  'service_name': ?instance.serviceName,
  'ssid': ?instance.ssid,
  'tls': ?instance.tls,
};
