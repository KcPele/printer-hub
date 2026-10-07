// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_health_report.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConnectionHealthReport _$ConnectionHealthReportFromJson(
  Map<String, dynamic> json,
) => ConnectionHealthReport(
  health: ConnectionHealth.fromJson(json['health'] as String),
  error: json['error'] as String?,
  latencyMs: (json['latency_ms'] as num?)?.toInt(),
);

Map<String, dynamic> _$ConnectionHealthReportToJson(
  ConnectionHealthReport instance,
) => <String, dynamic>{
  'error': instance.error,
  'health': instance.health,
  'latency_ms': instance.latencyMs,
};
