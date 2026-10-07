// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_read.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConnectionRead _$ConnectionReadFromJson(Map<String, dynamic> json) =>
    ConnectionRead(
      configuration: ConnectionConfigurationOutput.fromJson(
        json['configuration'] as Map<String, dynamic>,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      hasCredentials: json['has_credentials'] as bool,
      health: ConnectionHealth.fromJson(json['health'] as String),
      id: json['id'] as String,
      lastError: json['last_error'] as String?,
      lastFailureAt: json['last_failure_at'] == null
          ? null
          : DateTime.parse(json['last_failure_at'] as String),
      lastLatencyMs: (json['last_latency_ms'] as num?)?.toInt(),
      lastSuccessAt: json['last_success_at'] == null
          ? null
          : DateTime.parse(json['last_success_at'] as String),
      printerId: json['printer_id'] as String,
      priority: (json['priority'] as num).toInt(),
      purposes: (json['purposes'] as List<dynamic>)
          .map((e) => ConnectionPurpose.fromJson(e as String))
          .toList(),
      type: ConnectionType.fromJson(json['type'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$ConnectionReadToJson(ConnectionRead instance) =>
    <String, dynamic>{
      'configuration': instance.configuration,
      'created_at': instance.createdAt.toIso8601String(),
      'has_credentials': instance.hasCredentials,
      'health': instance.health,
      'id': instance.id,
      'last_error': instance.lastError,
      'last_failure_at': instance.lastFailureAt?.toIso8601String(),
      'last_latency_ms': instance.lastLatencyMs,
      'last_success_at': instance.lastSuccessAt?.toIso8601String(),
      'printer_id': instance.printerId,
      'priority': instance.priority,
      'purposes': instance.purposes,
      'type': instance.type,
      'updated_at': instance.updatedAt.toIso8601String(),
    };
