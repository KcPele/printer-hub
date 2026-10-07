// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'printer_read.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrinterRead _$PrinterReadFromJson(Map<String, dynamic> json) => PrinterRead(
  autoFallbackEnabled: json['auto_fallback_enabled'] as bool,
  capabilities: json['capabilities'] == null
      ? null
      : PrinterCapabilitiesOutput.fromJson(
          json['capabilities'] as Map<String, dynamic>,
        ),
  capabilitiesUpdatedAt: json['capabilities_updated_at'] == null
      ? null
      : DateTime.parse(json['capabilities_updated_at'] as String),
  connections: (json['connections'] as List<dynamic>)
      .map((e) => ConnectionRead.fromJson(e as Map<String, dynamic>))
      .toList(),
  createdAt: DateTime.parse(json['created_at'] as String),
  defaultConnectionId: json['default_connection_id'] as String?,
  friendlyName: json['friendly_name'] as String,
  id: json['id'] as String,
  lastSeenAt: json['last_seen_at'] == null
      ? null
      : DateTime.parse(json['last_seen_at'] as String),
  location: json['location'] as String?,
  manufacturer: json['manufacturer'] as String?,
  model: json['model'] as String?,
  organizationId: json['organization_id'] as String,
  serialNumber: json['serial_number'] as String?,
  status: PrinterStatus.fromJson(json['status'] as String),
  statusDetail: PrinterStatusDetailOutput.fromJson(
    json['status_detail'] as Map<String, dynamic>,
  ),
  updatedAt: DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$PrinterReadToJson(
  PrinterRead instance,
) => <String, dynamic>{
  'auto_fallback_enabled': instance.autoFallbackEnabled,
  'capabilities': ?instance.capabilities?.toJson(),
  'capabilities_updated_at': ?instance.capabilitiesUpdatedAt?.toIso8601String(),
  'connections': instance.connections.map((e) => e.toJson()).toList(),
  'created_at': instance.createdAt.toIso8601String(),
  'default_connection_id': ?instance.defaultConnectionId,
  'friendly_name': instance.friendlyName,
  'id': instance.id,
  'last_seen_at': ?instance.lastSeenAt?.toIso8601String(),
  'location': ?instance.location,
  'manufacturer': ?instance.manufacturer,
  'model': ?instance.model,
  'organization_id': instance.organizationId,
  'serial_number': ?instance.serialNumber,
  'status': instance.status.toJson(),
  'status_detail': instance.statusDetail.toJson(),
  'updated_at': instance.updatedAt.toIso8601String(),
};
