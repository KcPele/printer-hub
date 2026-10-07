// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'printer_create.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrinterCreate _$PrinterCreateFromJson(Map<String, dynamic> json) =>
    PrinterCreate(
      friendlyName: json['friendly_name'] as String,
      capabilities: json['capabilities'] == null
          ? null
          : PrinterCapabilitiesInput.fromJson(
              json['capabilities'] as Map<String, dynamic>,
            ),
      connections: (json['connections'] as List<dynamic>?)
          ?.map((e) => ConnectionCreate.fromJson(e as Map<String, dynamic>))
          .toList(),
      location: json['location'] as String?,
      manufacturer: json['manufacturer'] as String?,
      model: json['model'] as String?,
      serialNumber: json['serial_number'] as String?,
    );

Map<String, dynamic> _$PrinterCreateToJson(PrinterCreate instance) =>
    <String, dynamic>{
      'capabilities': instance.capabilities,
      'connections': instance.connections,
      'friendly_name': instance.friendlyName,
      'location': instance.location,
      'manufacturer': instance.manufacturer,
      'model': instance.model,
      'serial_number': instance.serialNumber,
    };
