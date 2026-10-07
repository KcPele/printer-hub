// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'printer_update.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrinterUpdate _$PrinterUpdateFromJson(Map<String, dynamic> json) =>
    PrinterUpdate(
      autoFallbackEnabled: json['auto_fallback_enabled'] as bool?,
      friendlyName: json['friendly_name'] as String?,
      location: json['location'] as String?,
      manufacturer: json['manufacturer'] as String?,
      model: json['model'] as String?,
      serialNumber: json['serial_number'] as String?,
    );

Map<String, dynamic> _$PrinterUpdateToJson(PrinterUpdate instance) =>
    <String, dynamic>{
      'auto_fallback_enabled': ?instance.autoFallbackEnabled,
      'friendly_name': ?instance.friendlyName,
      'location': ?instance.location,
      'manufacturer': ?instance.manufacturer,
      'model': ?instance.model,
      'serial_number': ?instance.serialNumber,
    };
