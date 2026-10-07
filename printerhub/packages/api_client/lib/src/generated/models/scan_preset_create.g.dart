// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_preset_create.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScanPresetCreate _$ScanPresetCreateFromJson(Map<String, dynamic> json) =>
    ScanPresetCreate(
      name: json['name'] as String,
      type: json['type'] as String,
      printerId: json['printer_id'] as String?,
      settings: json['settings'] == null
          ? null
          : ScanSettingsInput.fromJson(
              json['settings'] as Map<String, dynamic>,
            ),
      isDefault: json['is_default'] as bool? ?? false,
      scope: json['scope'] == null
          ? PresetScope.personal
          : PresetScope.fromJson(json['scope'] as String),
    );

Map<String, dynamic> _$ScanPresetCreateToJson(ScanPresetCreate instance) =>
    <String, dynamic>{
      'is_default': instance.isDefault,
      'name': instance.name,
      'printer_id': instance.printerId,
      'scope': instance.scope,
      'settings': instance.settings,
      'type': instance.type,
    };
